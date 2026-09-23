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

## Ticket #4451 — Cannot log in to the ACMU lab server (10 marks)

### The setup

`acmusrv` is a key-only account on this machine (the "lab server", reached on
its host-only address). The candidate's key pair is `~/.ssh/id_acmu`, its public
half is in `/home/acmusrv/.ssh/authorized_keys`, and `~/.ssh/config` carries an
`acmulab` alias. Everything server-side is correct and stays correct.

### Faults injected

| # | Fault | Symptom |
|---|---|---|
| 1 | the `IdentityFile` line is deleted from the `acmulab` block; `IdentitiesOnly yes` remains | ssh offers **no key at all** → `Permission denied (publickey)` |
| 2 | `~/.ssh/id_acmu` is `0644` | *UNPROTECTED PRIVATE KEY FILE*; the key is ignored → the same error |

Both print the identical one-line error. That is the point of the question.

### Diagnosis

```bash
ssh -v acmulab 2>&1 | grep -i 'identity file\|offering\|publickey'
```

With fault 1 present, ssh never says `Offering public key`. Once the
`IdentityFile` line is back it does — and then the permission refusal appears:

```
@@@ WARNING: UNPROTECTED PRIVATE KEY FILE! @@@
Permissions 0644 for '/home/candidate/.ssh/id_acmu' are too open.
```

### The fix

```bash
# 1 — put the key back into the alias
printf '    IdentityFile ~/.ssh/id_acmu\n' >> ~/.ssh/config   # or edit the block

# 2 — make the key private
chmod 600 ~/.ssh/id_acmu
```

### Verification

```bash
ssh -o BatchMode=yes acmulab whoami     # acmusrv
ls -l ~/.ssh/id_acmu                    # -rw-------
```

### Marks

| Check | Marks |
|---|---|
| `s8.identity` — `IdentityFile … id_acmu` in the alias | 2 |
| `s8.keyperm` — private key `0600` | 2 |
| `s8.connect` — logs in as `acmusrv`, key only | 6 |
| `s8.penpw` — gave `acmusrv` a password | −3 |
| `s8.pen777` — world-writable under `.ssh` | −3 |

### What to probe

- "Both faults printed the same error. How did you tell them apart?" — the only
  honest answer is `ssh -v`.
- "Why does ssh care about the mode of *your own* private key?"
- "What would `Connection refused` have meant instead?"
- "Ten machines to set up tomorrow — what do you do differently?"

---

## Marking at a glance

| Ticket | Raw | The one fault that separates candidates |
|---|---|---|
| #4419 disk | 14 | the unlinked-but-open file (`df` ≠ `du`) |
| #4423 permissions | 16 | the **setgid** bit |
| #4451 ssh login | 10 | reading `ssh -v` — two faults, one error message |
| **Total** | **40** | counts directly, no scaling |

Across all three, the scored shortcuts are `chmod 777`, adding the auditor to
the group, reformatting a filesystem, turning off sshd's `StrictModes`, and
and giving the key-only account a password. Each makes the symptom vanish. A candidate who scores well by
taking them is the specific failure mode this examination exists to catch —
weigh the penalties in panel discussion, not just in arithmetic.
