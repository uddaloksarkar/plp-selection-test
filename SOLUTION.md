# Solution key — Part B

> **Examiner only.** Do not print this with the ticket pack and do not leave it
> on a candidate machine. `bin/make-candidate-bundle.sh` copies only
> `scenarios/*/ticket.md`, so this file cannot reach the candidate bundle by
> accident — but it is in the repository that gets copied to the VM during
> provisioning, and `seal.sh` is what removes it again before the exam.

Three tickets, 40 marks, counted directly. Each carries several independent
faults in different layers, and each has at least one shortcut that clears the
symptom while losing marks.

---

## Ticket #4419 — Disk full on the lab file server (14 marks)

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

The collector allocates its spool **once per boot** (it records the fact in
`/run`), so restarting it reclaims the space for good during the sitting. A
reboot puts the fault back — which is what keeps the armed snapshot armed, and
is another reason rebooting is not the answer here.

### Verification

```bash
df -h /srv/data                          # under 10%
sudo lsof +L1 /srv/data                  # nothing large
df -i /srv/spool                         # inodes free
touch /srv/spool/incoming/t && rm /srv/spool/incoming/t
ls /srv/data/current                     # five CSVs, untouched
```

### Marks

| Check | Marks |
|---|---|
| `s2.space` — `/srv/data` under 10% | 4 |
| `s2.leak` — no large deleted-but-open file remains | 5 |
| `s2.current` — live data intact (sha256 manifest) | 2 |
| `s2.inodes` — spool accepts 200 new files | 3 |
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

## Ticket #4423 — Shared project folder unusable (16 marks)

### Faults injected

| # | Fault | Symptom |
|---|---|---|
| 1 | `chmod 0750` on the tree — drops **both** setgid and group write | members cannot write; new files get the creator's own group |
| 2 | `buddhadev` removed from the `acmu` group | one member locked out entirely |
| 3 | `notes.md` → `arnab:arnab 0600` | shared file became private |
| 4 | sudoers drop-in restarts **nginx** instead of **reportd** | valid syntax, wrong effect — `visudo -c` is clean |
| 5 | ACLs wiped with `setfacl -R -b` | auditor has no access |

### Diagnosis

```bash
stat -c '%a %U:%G %n' /srv/projects/acmu /srv/projects/acmu/shared/notes.md
id buddhadev
getfacl /srv/projects/acmu
sudo cat /etc/sudoers.d/acmu
```

`0750` is the giveaway for fault 1 — a shared group directory should be `2770`.
The leading `2` is the **setgid** bit: on a directory it makes new files inherit
the directory's group instead of the creator's primary group. That is exactly
Arnab's second complaint, and it is the single best discriminator in the paper —
most candidates fix `g+w` and stop.

### The fix

```bash
sudo chmod 2770 /srv/projects/acmu /srv/projects/acmu/shared
sudo gpasswd -a buddhadev acmu
sudo chown root:acmu /srv/projects/acmu/shared/notes.md
sudo chmod 0660 /srv/projects/acmu/shared/notes.md

sudo visudo -f /etc/sudoers.d/acmu
#   %acmu ALL=(root) NOPASSWD: /usr/bin/systemctl restart reportd

sudo setfacl -R  -m u:chandrima:rX /srv/projects/acmu
sudo setfacl -d  -m u:chandrima:rX /srv/projects/acmu
sudo setfacl -d  -m u:chandrima:rX /srv/projects/acmu/shared
```

The **default** ACL (`-d`) matters: without it, files created later are not
readable by the auditor and the access silently rots.

### Verification

```bash
sudo -u buddhadev touch /srv/projects/acmu/shared/t1
stat -c '%U:%G' /srv/projects/acmu/shared/t1     # must be *:acmu
sudo -u buddhadev cat /srv/projects/acmu/shared/notes.md
sudo -u arnab sudo -n systemctl restart reportd
sudo -u chandrima cat /srv/projects/acmu/shared/notes.md   # works
sudo -u chandrima touch /srv/projects/acmu/shared/t2       # must FAIL
```

### Marks

| Check | Marks |
|---|---|
| `s3.dirmode` — setgid + group write, not world-writable | 3 |
| `s3.dirgroup` — group is `acmu` | 1 |
| `s3.member` — `buddhadev` back in the group | 2 |
| `s3.groupwrite` — a member (arnab) creates a file **and it inherits group `acmu`** | 4 |
| `s3.notes` — `notes.md` is group `acmu`, group read-write | 2 |
| `s3.sudo` — sudoers points at the right unit | 2 |
| `s3.sudosyn` — drop-in still parses under `visudo -c` | 1 |
| `s3.aclread` — auditor can read | 1 |
| `s3.penacl` — auditor can **write** (over-granted) | −4 |
| `s3.pengrp` — auditor added to the group (explicitly forbidden) | −4 |
| `s3.pen777` — anything world-writable under `/srv/projects` | −5 |

### What to probe

- "What does the `2` in `2770` do, and what breaks silently without it?"
- "Why an ACL for the auditor rather than the group? What is the default ACL for?"
- "You added buddhadev back and his shell still says denied. Why?" (group changes
  need a new login session)
- "Why `visudo -f` and not an editor?" (a broken sudoers file locks out sudo
  for everyone)

---

## Ticket #4437 — The lab dashboard nobody can reach (10 marks)

### The setup

`labbox` is a network namespace on the VM (`10.20.0.2`) with an inbound-deny
nftables policy. Its dashboard listens on `127.0.0.1:8888` inside it.
`lab-tunnel.service` runs inside labbox and dials out:
`ssh -N -R 0.0.0.0:8080:localhost:8888 tunnel@gateway`. The `tunnel` account is
key-only (`restrict,port-forwarding`), with a `Match User tunnel` drop-in in
`/etc/ssh/sshd_config.d/60-lab-tunnel.conf`. `sudo labbox` is the candidate's
console into the namespace.

### Faults injected

| # | Part | Fault | Symptom |
|---|---|---|---|
| 1 | (a) | `authorized_keys` → `0666` | sshd: *bad ownership or modes*; tunnel: *Permission denied (publickey)*, restarts every 5 s |
| 2 | (b) | `-R …:localhost:8889` — dashboard is on `8888` | *connect_to localhost port 8889: failed* on every request |

### Diagnosis

```bash
journalctl -u lab-tunnel -n 5          # client side: denied
journalctl -u ssh -n 20                # server side: exactly why
sudo labbox ss -tlnp                   # dashboard really is on 127.0.0.1:8888
systemctl cat lab-tunnel               # ...but the tunnel sends to 8889
ss -tlnp | grep 8080                   # after (a): bound to 127.0.0.1 only
sudo sshd -T -C user=tunnel,host=labbox,addr=10.20.0.2 | grep gatewayports
```

### The fix

```bash
sudo chmod 600 /home/tunnel/.ssh/authorized_keys
sudo sed -i 's/localhost:8889/localhost:8888/' /etc/systemd/system/lab-tunnel.service
sudo sshd -t && sudo systemctl reload ssh
sudo systemctl daemon-reload && sudo systemctl restart lab-tunnel
```

### Verification

```bash
ss -tlnp | grep 8080                               # 0.0.0.0:8080 (sshd)
curl -s http://10.20.0.1:8080 | grep ACMU       # ACMU-DASHBOARD-OK
curl -s -m 3 http://10.20.0.2:8888 || echo blocked # labbox still unreachable
```

### Marks

| Check | Marks |
|---|---|
| `s7.keys` — (a) `authorized_keys` and its directories not group/world-writable, key present | 5 |
| `s7.target` — (b) `-R` forwards `8080` to `localhost:8888` | 5 |
| `s7.penstrict` — `StrictModes no` instead of fixing the file | −4 |
| `s7.penexpose` — labbox's dashboard reachable directly | −4 |
| `s7.penpass` — password login possible for `tunnel` | −3 |

### What to probe

- "Draw the tunnel. Which end listens, which connects?"
- "In `-R 0.0.0.0:8080:localhost:8888`, whose `localhost` is that?"
- "Why does sshd refuse a *correct* key because of file permissions?"
- "Is this tunnel a hole in campus IT's inbound policy? Who should sign off on it?"

---

## Marking at a glance

| Ticket | Raw | The one fault that separates candidates |
|---|---|---|
| #4419 disk | 14 | the unlinked-but-open file (`df` ≠ `du`) |
| #4423 permissions | 16 | the **setgid** bit |
| #4437 tunnel | 10 | `StrictModes` — sshd refuses a key file others could tamper with |
| **Total** | **40** | counts directly, no scaling |

Across all three, the scored shortcuts are `chmod 777`, adding the auditor to
the group, reformatting a filesystem, turning off sshd's `StrictModes`, and
opening labbox directly instead of fixing the tunnel. Each makes the symptom vanish. A candidate who scores well by
taking them is the specific failure mode this examination exists to catch —
weigh the penalties in panel discussion, not just in arithmetic.
