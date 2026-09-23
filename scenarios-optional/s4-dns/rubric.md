# S4 — Network / DNS (16 marks)

| id | marks | what it checks |
|---|---|---|
| s4.nsswitch | 3 | (a) `hosts: files dns` restored |
| s4.resolv | 3 | (b) `/etc/resolv.conf` sends queries to `127.0.0.1` |
| s4.dnsmasq | 2 | (c) service active **and** enabled |
| s4.viadns | 2 | (c) `dig @127.0.0.1 git.isi.local` answers `10.10.10.9` — the resolver itself works and its record is fixed |
| s4.hosts | 2 | (d) no `isi.local` name in `/etc/hosts` — the stale pin gone, none added |
| s4.www | 2 | (e) `www.isi.local` resolves end to end, inside 2 s |
| s4.portal | 1 | (e) `portal.isi.local` resolves end to end to `127.0.0.1` |
| s4.git | 1 | (e) `git.isi.local` resolves end to end to `10.10.10.9` |
| s4.penimm | −3 | `chattr +i /etc/resolv.conf` instead of fixing the cause |

## Faults injected
1. `/etc/resolv.conf` → `nameserver 10.255.255.53` (black hole; explains the multi-second hang).
2. `192.0.2.77 portal.isi.local` appended to `/etc/hosts` — explains why exactly one name "works" but wrongly.
3. `address=/git.isi.local/10.10.10.999` in `/etc/dnsmasq.d/isi-local.conf` — an invalid octet, so **dnsmasq refuses to start**. `journalctl -u dnsmasq` says so plainly.
4. `hosts: files` in `/etc/nsswitch.conf` — DNS is never consulted at all. This is the fault that defeats candidates who only think in terms of `resolv.conf`.

Each of (a)–(d) is checked with a test that bypasses the other layers — a
config line for (a) and (b), `dig @127.0.0.1` for (c), the hosts file for (d) —
so each part is marked independently. Only (e), the end-to-end lookups, needs
all four fixed. Before this split, 9 of the 16 marks were end-to-end, which made
the hosts-file shortcut worth far more than it is now.

## What separates a strong candidate
- Works down the stack in order instead of guessing: nsswitch → resolv.conf → is the resolver running → is the record right.
- Reads `journalctl -u dnsmasq` the moment `systemctl start dnsmasq` fails, instead of retrying it.
- **Refuses the `/etc/hosts` shortcut** even though it makes the symptom disappear. Pasting all five names into `/etc/hosts` earns only part (e)'s 4 marks, loses `s4.hosts`, and fixes none of layers (a)–(c) — probe it hard in the viva.
- Notices that `portal` answering *wrongly* is a different class of fault from the others.
- Checks that `systemd-resolved` is not fighting for port 53 rather than assuming.

## Viva follow-ups
- "Walk me through what happens between `ping www.isi.local` and the first packet."
- "Why was `portal` the only name that answered, and why was the answer wrong?"
- "You could have fixed all of this with `/etc/hosts` in thirty seconds. Why didn't you?"
- "How would you have found fault 4 if `journalctl` had been empty?"
