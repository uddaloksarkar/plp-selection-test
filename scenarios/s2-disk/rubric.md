# S2 — Disk space (16 marks)

| id | marks | what it checks |
|---|---|---|
| s2.space | 5 | `/srv/data` under 10% used |
| s2.leak | 5 | the unlinked-but-open 300 MB file reclaimed |
| s2.current | 2 | live data untouched (sha256 manifest) |
| s2.inodes | 4 | `/srv/spool` can create files again |
| s2.penfmt | −8 | reformatted/resized instead of diagnosing |
| s2.penmount | −6 | left a filesystem unmounted |

## Faults injected
1. `exam-metrics-collector` runs with `EXAM_LEAK=1`: it writes 300 MB to `/srv/data/.cache/metrics.spool`, unlinks it, and keeps the fd open. `du` cannot see it; only `lsof +L1`, `lsof -nP +D /srv/data | grep deleted`, or walking `/proc/*/fd` finds it. Fix = restart the unit.
2. `/srv/data/archive/dump-2025-{06..09}.tar.gz` fill the remainder. These are genuinely safe to delete and `README.txt` says so.
3. `/srv/spool` (48 MB, 2048 inodes) has ~1900 lock files in `/srv/spool/stale` → `ENOSPC` with free blocks. Only `df -i` reveals it.

**Deleting the dumps alone is not enough to reach 10%** — the candidate must find the leak too. That is deliberate.

## What separates a strong candidate
- Runs `df -h`, `df -i`, `du -xh --max-depth=1 /srv/data | sort -h` as a reflex.
- Reaches for `lsof` / `/proc/*/fd` when `du` and `df` disagree, and *restarts the service* rather than rebooting the box.
- Reads `README.txt` before deleting anything, and does not touch `current/`.
- Explains inode exhaustion in their own words in the FIXLOG.
- Weak signal: reboots the VM. It does clear the leak — mark it down and probe in the viva ("what if this were the production file server at 11am?").

## Viva follow-ups
- "You restarted the collector and the space came back. What exactly was holding it?"
- "How would you stop this recurring next month?" (logrotate + `copytruncate` vs `postrotate` reload, monitoring on both `df` and `df -i`, quota.)
- "The spool is 48 MB with 2048 inodes. How would you size it properly?"
