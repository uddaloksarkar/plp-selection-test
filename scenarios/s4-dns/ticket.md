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

## 1. What exactly is the problem

Name resolution for the `isi.local` zone is broken on this host. One name
answers with a **wrong** address, which is a different fault from the rest.

This host runs its own resolver (**dnsmasq**) which serves the `isi.local` zone
and forwards everything else upstream. These are the addresses it is supposed to
hand out:

| name | address |
|---|---|
| `www.isi.local` | 127.0.0.1 |
| `statlab.isi.local` | 127.0.0.1 |
| `portal.isi.local` | 127.0.0.1 |
| `git.isi.local` | 10.10.10.9 |
| `nas.isi.local` | 10.10.10.20 |

## 2. How to reproduce it

```bash
getent hosts www.isi.local        # nothing, after a long pause
getent hosts git.isi.local        # nothing
getent hosts portal.isi.local     # answers 192.0.2.77 — wrong address
```

Ask the resolver directly, which bypasses most of the system's lookup path:

```bash
dig +short @127.0.0.1 git.isi.local
systemctl status dnsmasq
```

## 3. What to fix

1. All five names resolve to the correct addresses, for every user on this
   host, and answer in **under a second**.
2. The answers come from the resolver, not from a local file.
3. It still works after a reboot.

## 4. How to check you have fixed it

```bash
for n in www statlab portal git nas; do
  printf '%-22s %s\n' "$n.isi.local" "$(getent hosts $n.isi.local | awk '{print $1}')"
done
```

All five must print the address from the table above, and the whole loop should
finish instantly rather than pausing.

```bash
dig +short @127.0.0.1 git.isi.local     # must print 10.10.10.9
```
```bash
grep -i isi.local /etc/hosts            # must print nothing at all
```
```bash
systemctl is-active dnsmasq; systemctl is-enabled dnsmasq   # active, enabled
```

## Constraints — these are marked

- **Do not put `isi.local` names into `/etc/hosts`.** The systems group will not
  maintain hosts files across forty machines. It makes the symptom disappear and
  **loses marks**.
- Do not make `/etc/resolv.conf` immutable (`chattr +i`) to hold a fix in place.

## Notes

- There is more than one fault, and they are in different layers. A useful order
  to think in: *is a DNS query being sent at all? where is it being sent? is
  anything answering? is the answer correct?*
- A service that refuses to start will usually say why, in its own log.
- The long pause before failure is itself a clue about which layer is wrong.
- Worth knowing about: `getent hosts`, `dig`, `resolvectl`, `/etc/resolv.conf`,
  `/etc/nsswitch.conf`, `/etc/dnsmasq.d/`, `journalctl -u dnsmasq`. Not all of
  them are relevant.
- Record symptom, cause, change and verification in `~/FIXLOG.md`.
