# S4 — Network / DNS (16 marks)

| id | marks | what it checks |
|---|---|---|
| s4.www | 3 | basic resolution restored, inside 2 s |
| s4.portal | 3 | the stale `/etc/hosts` pin removed |
| s4.git | 3 | the invalid zone record corrected |
| s4.viadns | 2 | `dig @127.0.0.1` answers — i.e. the resolver really works |
| s4.hosts | 2 | no `isi.local` name was hard-coded into `/etc/hosts` |
| s4.dnsmasq | 2 | service active **and** enabled |
| s4.nsswitch | 1 | `hosts: files dns` restored |
| s4.penimm | −3 | `chattr +i /etc/resolv.conf` instead of fixing the cause |

## Faults injected
1. `/etc/resolv.conf` → `nameserver 10.255.255.53` (black hole; explains the multi-second hang).
2. `192.0.2.77 portal.isi.local` appended to `/etc/hosts` — explains why exactly one name "works" but wrongly.
3. `address=/git.isi.local/10.10.10.999` in `/etc/dnsmasq.d/isi-local.conf` — an invalid octet, so **dnsmasq refuses to start**. `journalctl -u dnsmasq` says so plainly.
4. `hosts: files` in `/etc/nsswitch.conf` — DNS is never consulted at all. This is the fault that defeats candidates who only think in terms of `resolv.conf`.

## What separates a strong candidate
- Works down the stack in order instead of guessing: nsswitch → resolv.conf → is the resolver running → is the record right.
- Reads `journalctl -u dnsmasq` the moment `systemctl start dnsmasq` fails, instead of retrying it.
- **Refuses the `/etc/hosts` shortcut** even though it makes the symptom disappear. Candidates who paste all five names into `/etc/hosts` lose `s4.viadns` and `s4.hosts` and should be probed hard in the viva.
- Notices that `portal` answering *wrongly* is a different class of fault from the others.
- Checks that `systemd-resolved` is not fighting for port 53 rather than assuming.

## Viva follow-ups
- "Walk me through what happens between `ping www.isi.local` and the first packet."
- "Why was `portal` the only name that answered, and why was the answer wrong?"
- "You could have fixed all of this with `/etc/hosts` in thirty seconds. Why didn't you?"
- "How would you have found fault 4 if `journalctl` had been empty?"
