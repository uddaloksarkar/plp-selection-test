# TICKET #4431 — Campus names stopped resolving on this host

**Raised by:** Systems group · **Priority:** High
**Assigned:** you · **Host:** this machine · **Raised:** after last night's patching window

> "This host can't resolve any campus name since the patching window.
> `ping www.isi.local` sits there for several seconds and then fails.
>
> The odd one is `portal.isi.local` — that *does* answer, but with an address
> that hasn't been ours since 2023, so the portal client connects to nothing at
> all. Please don't paper over this with hosts-file entries; we have forty more
> machines behind this one."

## Background: how this host looks up a name

When a program asks for `www.isi.local`, the answer passes through a chain of
layers. Each layer has its own configuration, and **each can break on its own**:

```
program (ping, getent, a browser …)
  │
  ├─ 1. /etc/nsswitch.conf    the "hosts:" line says WHERE to look, in order:
  │                           "files" = /etc/hosts,  "dns" = ask a DNS server
  │
  ├─ 2. /etc/hosts            a fixed local list, checked when "files" is listed
  │
  ├─ 3. /etc/resolv.conf      the "nameserver" line says WHICH DNS server to ask
  │
  └─ 4. dnsmasq on 127.0.0.1  the campus DNS server running on this host; its
                              records live in /etc/dnsmasq.d/isi-local.conf
```

The campus resolver is **dnsmasq, listening on 127.0.0.1**. It serves the
`isi.local` zone and forwards everything else upstream. These are the addresses
it is supposed to hand out:

| name | address |
|---|---|
| `www.isi.local` | 127.0.0.1 |
| `acmu.isi.local` | 127.0.0.1 |
| `portal.isi.local` | 127.0.0.1 |
| `git.isi.local` | 10.10.10.9 |
| `nas.isi.local` | 10.10.10.20 |

## Four separate problems, and a final check

The patching window broke **four layers independently**. Each part below is
about one layer, is checked with a command that tests only that layer, and is
marked on its own. Tackle them in any order.

Names only resolve end to end once all four layers work, so part (e) checks
them together.

| | Layer | Marks |
|---|---|---|
| **(a)** | `/etc/nsswitch.conf` — is DNS consulted at all? | 3 |
| **(b)** | `/etc/resolv.conf` — are queries sent to the right server? | 3 |
| **(c)** | dnsmasq — is the campus resolver running, and are its records right? | 4 |
| **(d)** | `/etc/hosts` — is a stale local entry overriding DNS? | 2 |
| **(e)** | everything together — do all five names resolve, quickly? | 4 |

---

## (a) Is DNS consulted at all?

**Problem.** The `hosts:` line in `/etc/nsswitch.conf` decides where the system
looks for names. If `dns` is not on it, the system never asks a DNS server,
however well the rest is configured.

**Reproduce.**
```bash
grep ^hosts /etc/nsswitch.conf
```

**Fix.** The system must check `/etc/hosts` first and then DNS, as a standard
Ubuntu host does.

**Check.**
```bash
grep ^hosts /etc/nsswitch.conf          # must list: files dns
```

---

## (b) Are queries sent to the right server?

**Problem.** The `nameserver` line in `/etc/resolv.conf` says which DNS server
to send queries to. It should be the campus resolver on this host.

**Reproduce.**
```bash
cat /etc/resolv.conf
```
The long pause before failure that the systems group noticed is a clue about
this layer: a server that does not exist never answers, so every lookup waits
for the timeout.

**Fix.** Send queries to the campus resolver at `127.0.0.1`. Change the file
itself; do not lock it with `chattr`.

**Check.**
```bash
grep ^nameserver /etc/resolv.conf       # must be: nameserver 127.0.0.1
```

---

## (c) Is the campus resolver running, with the right records?

**Problem.** dnsmasq is not running, so nothing answers on `127.0.0.1`. It
refuses to start, and says why in its own log.

**Reproduce.**
```bash
systemctl status dnsmasq
journalctl -u dnsmasq -n 20
```

**Fix.** Get dnsmasq running, starting at every boot, and serving the addresses
in the table above. Its records are in `/etc/dnsmasq.d/isi-local.conf`.

**Check.** `dig @127.0.0.1` asks dnsmasq directly, bypassing layers 1–3, so this
tests dnsmasq on its own:
```bash
systemctl is-active dnsmasq; systemctl is-enabled dnsmasq    # active, enabled
dig +short @127.0.0.1 git.isi.local                          # 10.10.10.9
```

---

## (d) Is a stale local entry overriding DNS?

**Problem.** `portal.isi.local` answers, but with the wrong address. An entry in
`/etc/hosts` is checked before DNS, so a stale one wins over the resolver.

**Reproduce.**
```bash
getent -s files hosts portal.isi.local  # answers 192.0.2.77 from /etc/hosts
```
`getent -s files` looks **only** in `/etc/hosts`, so it tests this layer alone.

**Fix.** Remove the stale entry. Do **not** add any `isi.local` names to
`/etc/hosts`: the systems group will not maintain hosts files across forty
machines.

**Check.**
```bash
grep -i isi.local /etc/hosts            # must print nothing at all
```

---

## (e) Everything together

Once (a)–(d) are all fixed, every name should resolve through the whole chain,
instantly and correctly, for every user on this host:

```bash
for n in www acmu portal git nas; do
  printf '%-22s %s\n' "$n.isi.local" "$(getent hosts $n.isi.local | awk '{print $1}')"
done
```

All five must print the address from the table above, and the loop should
finish instantly rather than pausing. If one name is still wrong or slow, go
back through (a)–(d): one layer is still broken. The fix must also survive a
reboot.

## Constraints — these apply to every part, and are marked

- **Do not put `isi.local` names into `/etc/hosts`.** It makes the symptom
  disappear and **loses marks**.
- Do not make `/etc/resolv.conf` immutable (`chattr +i`) to hold a fix in place.

## Notes

- Worth knowing about: `getent hosts`, `getent -s files hosts`, `dig`,
  `resolvectl`, `systemctl`, `journalctl -u dnsmasq`. Not all of them are
  relevant.
- Record symptom, cause, change and verification in `~/FIXLOG.md`, one entry
  for each part.
