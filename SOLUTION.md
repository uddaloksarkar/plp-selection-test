# Solution key — Part B

> **Examiner only.** Do not print this with the ticket pack and do not leave it
> on a candidate machine. `bin/make-candidate-bundle.sh` copies only
> `scenarios/*/ticket.md`, so this file cannot reach the candidate bundle by
> accident — but it is in the repository that gets copied to the VM during
> provisioning, and `seal.sh` is what removes it again before the exam.

Three tickets, 50 raw marks, scaled to 45. Each carries several independent
faults in different layers, and each has at least one shortcut that clears the
symptom while losing marks.

---

## Ticket #4419 — Disk full on the lab file server (16 marks)

### Faults injected

| # | Fault | Symptom it produces |
|---|---|---|
| 1 | `exam-metrics-collector` holds a ~300 MB **unlinked but still open** file at `/srv/data/.cache/metrics.spool` | `df` and `du` disagree; the space cannot be found |
| 2 | `/srv/data/archive/dump-2025-{06..09}.tar.gz` fill the remaining space | `/srv/data` at 100% |
| 3 | ~1900 zero-byte lock files in `/srv/spool/stale` exhaust the **inodes** | `ENOSPC` on a filesystem with free blocks |

Deleting the archives alone leaves `/srv/data` around 30% used — short of the
10% gate. That is deliberate: it forces the candidate to find fault 1.

### Diagnosis

```bash
df -h /srv/data          # 100% used
sudo du -sh /srv/data    # far less than df claims
```

Unlinking a file removes its directory entry; the blocks are freed only when the
last open file descriptor closes. `du` walks directory entries so cannot see it.
`df` reads the filesystem's free-block count, so it can.

```bash
sudo lsof +L1 /srv/data                   # link count < 1 = deleted but open
sudo lsof -nP +D /srv/data | grep deleted
sudo ls -l /proc/*/fd/* 2>/dev/null | grep '/srv/data.*deleted'   # no lsof needed
```

For the spool, the whole answer is one flag:

```bash
df -h /srv/spool     # space free
df -i /srv/spool     # IUse 100%
```

Inode count is fixed at `mkfs` time; every file consumes one regardless of size.
`creat()` then returns `ENOSPC` — the same errno as "disk full", which is why
the message misleads.

### The fix

```bash
sudo systemctl restart exam-metrics-collector      # releases the held file
cat /srv/data/archive/README.txt                   # confirms the dumps are safe
sudo rm /srv/data/archive/dump-2025-*.tar.gz
sudo rm -rf /srv/spool/stale                       # the runaway cron's locks
```

`reportd` will not resume by itself: with the filesystem genuinely full its
writes fail, so it must be restarted once space exists.

The collector allocates its spool **once per boot** (it records the fact in
`/run`), so restarting it reclaims the space for good during the sitting. A
reboot puts the fault back — which is what keeps the armed snapshot armed, and
is another reason rebooting is not the answer here.

### Verification

```bash
df -h /srv/data                          # under 10%
sudo lsof +L1 /srv/data                  # nothing large
tail -1 /srv/data/logs/reportd.log; date # timestamps match
df -i /srv/spool                         # inodes free
touch /srv/spool/incoming/t && rm /srv/spool/incoming/t
ls /srv/data/current                     # five CSVs, untouched
```

### Marks

| Check | Marks |
|---|---|
| `s2.space` — `/srv/data` under 10% | 4 |
| `s2.leak` — no large deleted-but-open file remains | 4 |
| `s2.reportd` — log being written again | 2 |
| `s2.current` — live data intact (sha256 manifest) | 2 |
| `s2.inodes` — spool accepts 200 new files | 4 |
| `s2.penfmt` — filesystem recreated or resized | −8 |
| `s2.penmount` — a filesystem left unmounted | −6 |

### What to probe

- **Rebooting** clears the leak and scores the marks. Wrong instinct, and the
  ticket says so. Ask what they would do on a production file server at 11am.
- Ask them to explain what an inode *is*. "It ran out of inodes" without that is
  pattern-matching, not understanding.
- Did they read `README.txt` before deleting? Ask what they would have done if
  it had said the opposite.

---

## Ticket #4423 — Shared project folder unusable (18 marks)

### Faults injected

| # | Fault | Symptom |
|---|---|---|
| 1 | `chmod 0755` on the tree — drops **both** setgid and group write | members cannot write; new files get the creator's own group |
| 2 | `bikram` removed from the `statlab` group | one member locked out entirely |
| 3 | `notes.md` → `anita:anita 0600` | shared file became private |
| 4 | sudoers drop-in restarts **nginx** instead of **reportd** | valid syntax, wrong effect — `visudo -c` is clean |
| 5 | ACLs wiped with `setfacl -R -b` | auditor has no access |

### Diagnosis

```bash
stat -c '%a %U:%G %n' /srv/projects/statlab /srv/projects/statlab/shared/notes.md
id bikram
getfacl /srv/projects/statlab
sudo cat /etc/sudoers.d/statlab
```

`0755` is the giveaway for fault 1 — a shared group directory should be `2775`.
The leading `2` is the **setgid** bit: on a directory it makes new files inherit
the directory's group instead of the creator's primary group. That is exactly
Anita's second complaint, and it is the single best discriminator in the paper —
most candidates fix `g+w` and stop.

### The fix

```bash
sudo chmod 2775 /srv/projects/statlab /srv/projects/statlab/shared
sudo gpasswd -a bikram statlab
sudo chown root:statlab /srv/projects/statlab/shared/notes.md
sudo chmod 0664 /srv/projects/statlab/shared/notes.md

sudo visudo -f /etc/sudoers.d/statlab
#   %statlab ALL=(root) NOPASSWD: /usr/bin/systemctl restart reportd

sudo setfacl -R  -m u:chandan:rX /srv/projects/statlab
sudo setfacl -d  -m u:chandan:rX /srv/projects/statlab
sudo setfacl -d  -m u:chandan:rX /srv/projects/statlab/shared
```

The **default** ACL (`-d`) matters: without it, files created later are not
readable by the auditor and the access silently rots.

### Verification

```bash
sudo -u bikram touch /srv/projects/statlab/shared/t1
stat -c '%U:%G' /srv/projects/statlab/shared/t1     # must be *:statlab
sudo -u bikram cat /srv/projects/statlab/shared/notes.md
sudo -u anita sudo -n systemctl restart reportd
sudo -u chandan cat /srv/projects/statlab/shared/notes.md   # works
sudo -u chandan touch /srv/projects/statlab/shared/t2       # must FAIL
```

### Marks

| Check | Marks |
|---|---|
| `s3.dirmode` — setgid + group write, not world-writable | 3 |
| `s3.dirgroup` — group is `statlab` | 1 |
| `s3.member` — `bikram` back in the group | 3 |
| `s3.groupwrite` — creates a file **and it inherits group `statlab`** | 4 |
| `s3.notes` — `notes.md` ownership/mode fixed | 2 |
| `s3.sudo` — sudoers points at the right unit | 3 |
| `s3.sudosyn` — drop-in still parses under `visudo -c` | 1 |
| `s3.aclread` — auditor can read | 1 |
| `s3.penacl` — auditor can **write** (over-granted) | −4 |
| `s3.pengrp` — auditor added to the group (explicitly forbidden) | −4 |
| `s3.pen777` — anything world-writable under `/srv/projects` | −5 |

### What to probe

- "What does the `2` in `2775` do, and what breaks silently without it?"
- "Why an ACL for the auditor rather than the group? What is the default ACL for?"
- "You added bikram back and his shell still says denied. Why?" (group changes
  need a new login session)
- "Why `visudo -f` and not an editor?" (a broken sudoers file locks out sudo
  for everyone)

---

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
for n in www statlab portal git nas; do
  printf '%-22s %s\n' "$n.isi.local" "$(getent hosts $n.isi.local | awk '{print $1}')"
done
dig +short @127.0.0.1 git.isi.local     # 10.10.10.9
grep -i isi.local /etc/hosts            # nothing
systemctl is-active dnsmasq; systemctl is-enabled dnsmasq
```

### Marks

| Check | Marks |
|---|---|
| `s4.www` — resolves, inside 2 s | 3 |
| `s4.portal` — stale `/etc/hosts` pin removed | 3 |
| `s4.git` — invalid zone record corrected | 3 |
| `s4.viadns` — `dig @127.0.0.1` answers | 2 |
| `s4.hosts` — no `isi.local` hard-coded in `/etc/hosts` | 2 |
| `s4.dnsmasq` — active **and** enabled | 2 |
| `s4.nsswitch` — `hosts: files dns` restored | 1 |
| `s4.penimm` — `chattr +i /etc/resolv.conf` instead of fixing the cause | −3 |

### What to probe

- "Walk me from `ping www.isi.local` to the first packet on the wire."
- "Why was `portal` the only name that answered, and why was it wrong?"
- "You could have fixed all of this with `/etc/hosts` in thirty seconds. Why
  didn't you?" — the honesty test of the paper.
- "How would you have found fault 4 with no logs at all?"

---

## Marking at a glance

| Ticket | Raw | The one fault that separates candidates |
|---|---|---|
| #4419 disk | 16 | the unlinked-but-open file (`df` ≠ `du`) |
| #4423 permissions | 18 | the **setgid** bit |
| #4431 DNS | 16 | `nsswitch.conf` — DNS not in the lookup path at all |
| **Total** | **50** | scaled to 45 of 100 |

Across all three, the scored shortcuts are `chmod 777`, adding the auditor to
the group, hard-coding names into `/etc/hosts`, reformatting a filesystem, and
`chattr +i`. Each makes the symptom vanish. A candidate who scores well by
taking them is the specific failure mode this examination exists to catch —
weigh the penalties in panel discussion, not just in arithmetic.
