# TICKET #4437 — The lab dashboard nobody can reach

**Raised by:** Arnab Basu, ACMU Lab · **Priority:** High
**Assigned:** you · **Host:** this machine (`gateway`) · **Raised:** Monday, after Friday's maintenance

> "Our results dashboard has been down since Friday's maintenance. We open
> `http://gateway:8080` and get nothing. Somebody said the tunnel service on
> labbox keeps restarting. We need it back before the review meeting."

## Background: how the dashboard gets out of the basement

The dashboard runs on **`labbox`**, a machine in the basement lab. Campus IT's
firewall lets labbox make connections **out**, but nothing may connect **in**
to it. So labbox publishes the dashboard through this machine, **`gateway`**,
with a *reverse SSH tunnel*:

```
 colleagues ──▶ gateway:8080 ═══════ SSH tunnel ═══════▶ labbox ──▶ 127.0.0.1:8888
               (this machine)   ◀── labbox dials OUT ──   (nothing   (the dashboard)
                                                          gets IN)
```

labbox runs, as the service `lab-tunnel`:

```bash
ssh -N -R 0.0.0.0:8080:localhost:8888 tunnel@gateway
```

`-R [bind_address:]port:host:hostport` means: *log in to gateway, and ask
**gateway** to listen on `bind_address:port`; every connection that arrives
there is sent back through the tunnel, and labbox passes it on to
`host:hostport` as labbox sees it.* So `localhost` in that command is labbox's
own localhost, not gateway's.

| | Machine | Address | You get there with |
|---|---|---|---|
| gateway | this VM | `10.20.0.1` (and the address you logged in to) | you are already here |
| labbox | the basement machine | `10.20.0.2` | `sudo labbox` — its console (nothing can reach it over the network) |

labbox is simulated on this VM, so it shares its files. Its own files are under
`/opt/labbox/`, and its services are `labbox-dashboard` and `lab-tunnel`
(`systemctl status lab-tunnel`, `journalctl -u lab-tunnel`).

## Two separate problems

Friday's maintenance broke the tunnel in **two independent places**: one about
logging in, one about where the tunnel leads. Each has its own cause and fix,
and is marked on its own. Fixing one does nothing for the other. Take them in
either order, although you will only *see* (b) in action once (a) lets the
tunnel log in.

| | What is wrong | Where | Marks |
|---|---|---|---|
| **(a)** | gateway refuses labbox's key | gateway | 5 |
| **(b)** | the tunnel leads to the wrong place on labbox | labbox | 5 |

---

## (a) gateway refuses labbox's key

**Problem.** labbox logs in to gateway as the user `tunnel`, with a key and no
password. gateway is rejecting that key, so the tunnel never comes up and the
service restarts every few seconds.

**Reproduce.**
```bash
journalctl -u lab-tunnel -n 5          # "Permission denied (publickey…)"
journalctl -u ssh -n 20                # gateway's side: says exactly why
```

**Fix.** Make gateway accept the key again. The key itself is correct; sshd
refuses to use an `authorized_keys` file that other people could have tampered
with.

**Check.**
```bash
ls -l /home/tunnel/.ssh/authorized_keys          # only tunnel can write to it
journalctl -u ssh -n 5                           # "Accepted publickey for tunnel"
```

---

## (b) The tunnel leads to the wrong place

**Problem.** The tunnel's `-R` setting decides where on labbox each connection
ends up. It must lead to the dashboard.

**Reproduce.**
```bash
sudo labbox ss -tlnp                   # what is actually listening on labbox
systemctl cat lab-tunnel               # where the tunnel sends connections
```
Once (a) is fixed, a request through the tunnel shows this fault in the
tunnel's log as `connect_to localhost port …: failed`.

**Fix.** Correct the tunnel in `/etc/systemd/system/lab-tunnel.service`, then
`systemctl daemon-reload` and `systemctl restart lab-tunnel`.

**Check.**
```bash
systemctl cat lab-tunnel | grep -- -R  # ends in localhost:8888
curl -s http://localhost:8080 | head -3   # (once (a) is fixed) the dashboard
```

---

## When both are done

```bash
curl -s http://10.20.0.1:8080 | grep ACMU   # ACMU-DASHBOARD-OK
```

You can also open `http://<the address you logged in to>:8080` in a browser on
your own machine. That is what the colleagues see.

## Constraints — these apply to every part, and are marked

- **Do not turn off `StrictModes`** (or any other sshd safety check) to make the
  key work. Fix the file.
- **labbox must stay unreachable.** Do not loosen its firewall or move the
  dashboard off `127.0.0.1`: going round the tunnel is not fixing it.
- Do not give the `tunnel` account a password or a login shell.
- Always run `sudo sshd -t` before reloading sshd. A broken sshd configuration
  can lock everyone out, you included.

## Notes

- `sudo labbox` opens a root shell on labbox; `sudo labbox <command>` runs one
  command there. Type `exit` to come back.
- Worth knowing about: `journalctl -u`, `ss -tlnp`, `systemctl cat`,
  `sshd -t`, `sshd -T`, `man ssh` (look for `-R`), `man sshd_config`. Not all of
  them are relevant.
- Record symptom, cause, change and verification in `~/FIXLOG.md`, one entry
  for each part.
