# Q1 — Disk full on the lab file server · 14 marks

*Reported by Debarshi, research scholar:*

> "I cannot copy anything into `/srv/data`, it says the disk is full, and
> nothing I can see in there accounts for that much space. Submitting a job
> into `/srv/spool` *also* says the disk is full, but `df -h` shows that one
> has plenty of space left. That part makes no sense to me."

## Background: this server has three separate disks

`/srv/data` and `/srv/spool` look like ordinary folders, but each one is really
its own small disk, attached at that path (a *mount point*). The rest of the
system lives on a third, much larger disk.

| path | | size |
|---|---|---|
| `/` | the system disk | about 24 GB |
| `/srv/data` | the project data disk | 1 GB |
| `/srv/spool` | the job-submission disk | 48 MB |

Though the two complaints look alike, they are **two unrelated faults on two
different disks**, with different causes. Fixing one does nothing for the other.

| | What is wrong | Marks |
|---|---|---|
| **(a)** | `/srv/data` is full | 11 |
| **(b)** | `/srv/spool` refuses new files | 3 |

---

## (a) `/srv/data` is full · 11 marks

`/srv/data` is at 100%, and the files you can see there do not add up to the
space reported.

**Reproduce.**
```bash
df -h /srv/data                        # 100% used
sudo du -sh /srv/data                  # much smaller than df says is in use
```

**Fix.** Bring `/srv/data` back to **under 10% used** (the `Use%` column of
`df -h`). There is more than one reason this disk is full: freeing the largest
files may not work. Observe the differences shown in the output of `df` and
`du`. **Explain the reason behind the difference.**

**Check.**
```bash
df -h /srv/data                       # Use% under 10%
ls /srv/data/current                  # five survey-block CSV files, still there
```

---

## (b) `/srv/spool` refuses new files · 3 marks

New files cannot be created on `/srv/spool`, *although `df -h` reports free
space on it*. Something other than free space has run out. This has nothing to
do with `/srv/data`.

**Reproduce.**
```bash
df -h /srv/spool                       # shows space free
touch /srv/spool/incoming/testjob      # "No space left on device"
```

**Fix.** Make `/srv/spool` able to accept new files again. The current problem
is not due to a lack of free space on the disk. **Explain why `/srv/spool`
reported "No space left on device" while `df -h` showed free space.**

**Check.**
```bash
touch /srv/spool/incoming/t && echo OK && rm /srv/spool/incoming/t
```

---

## Constraints

- Nothing under `/srv/data/current` may be deleted or changed.
- `/srv/data/archive/README.txt` says what is safe to remove there. Read it
  before deleting anything.
