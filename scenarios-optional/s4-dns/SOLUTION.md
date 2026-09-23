# Solution key — optional DNS scenario

(Moved out of the main SOLUTION.md when `s7-tunnel` replaced it.)

## Ticket #4431 — Campus names stopped resolving (16 marks)

### Faults injected

| # | Fault | Symptom |
|---|---|---|
| 1 | `/etc/resolv.conf` → `nameserver 10.255.255.53` (black hole) | multi-second hang, then failure |
| 2 | `192.0.2.77 portal.isi.local` appended to `/etc/hosts` | exactly one name answers, wrongly |
| 3 | `address=/git.isi.local/10.10.10.999` — invalid octet | **dnsmasq refuses to start** |
| 4 | `hosts: files` in `/etc/nsswitch.conf` — DNS never consulted | defeats anyone who only thinks about `resolv.conf` |

### Diagnosis

Work down the stack rather than guessing:

```bash
grep ^hosts /etc/nsswitch.conf     # is DNS in the path at all?
cat /etc/resolv.conf               # where are queries being sent?
systemctl status dnsmasq           # is anything answering?
journalctl -u dnsmasq -n 20        # it says exactly why it will not start
grep -n isi.local /etc/hosts       # explains the one wrong answer
```

The multi-second pause before failure is itself the clue for fault 1 — a
blackholed resolver times out rather than refusing.

### The fix

```bash
sudo sed -i 's/^nameserver .*/nameserver 127.0.0.1/' /etc/resolv.conf
sudo sed -i '/isi\.local/d' /etc/hosts
sudo sed -i 's|^address=/git.isi.local/.*|address=/git.isi.local/10.10.10.9|' \
        /etc/dnsmasq.d/isi-local.conf
sudo sed -i 's/^hosts:.*/hosts:          files dns/' /etc/nsswitch.conf
sudo systemctl enable --now dnsmasq
```

### Verification

```bash
for n in www acmu portal git nas; do
  printf '%-22s %s\n' "$n.isi.local" "$(getent hosts $n.isi.local | awk '{print $1}')"
done
dig +short @127.0.0.1 git.isi.local     # 10.10.10.9
grep -i isi.local /etc/hosts            # nothing
systemctl is-active dnsmasq; systemctl is-enabled dnsmasq
```

### Marks

| Check | Marks |
|---|---|
| `s4.nsswitch` — (a) `hosts: files dns` restored | 3 |
| `s4.resolv` — (b) `resolv.conf` → `nameserver 127.0.0.1` | 3 |
| `s4.dnsmasq` — (c) active **and** enabled | 2 |
| `s4.viadns` — (c) `dig @127.0.0.1` answers, invalid record corrected | 2 |
| `s4.hosts` — (d) no `isi.local` in `/etc/hosts` | 2 |
| `s4.www` — (e) resolves end to end, inside 2 s | 2 |
| `s4.portal` — (e) resolves end to end, not the stale pin | 1 |
| `s4.git` — (e) resolves end to end | 1 |
| `s4.penimm` — `chattr +i /etc/resolv.conf` instead of fixing the cause | −3 |

### What to probe

- "Walk me from `ping www.isi.local` to the first packet on the wire."
- "Why was `portal` the only name that answered, and why was it wrong?"
- "You could have fixed all of this with `/etc/hosts` in thirty seconds. Why
  didn't you?" — the honesty test of the paper.
- "How would you have found fault 4 with no logs at all?"
