# TICKET #4419 — "Disk full" on the lab file server

**Raised by:** Debarshi Roy, research scholar · **Priority:** High
**Assigned:** you · **Host:** this machine · **Raised:** 06:55 today

> "Three of us have hit this since this morning.
>
> 1. I can't copy anything into `/srv/data` — it says the disk is full, and
>    nothing I can see in there accounts for that much space.
> 2. Submitting a job into `/srv/spool` *also* says the disk is full, but
>    `df -h` shows that one has plenty of space left. That part makes no sense
>    to me.
>
> I haven't deleted anything, I didn't want to make it worse."

## Background: this server has three separate disks

`/srv/data` and `/srv/spool` look like ordinary folders, but each one is really
its own small disk, attached at that path (a *mount point*). The rest of the
system lives on a third, much larger disk.

| Path | What it is | Size |
|---|---|---|
| `/` | the system disk | about 24 GB |
| `/srv/data` | the project data disk | 1 GB |
| `/srv/spool` | the job-submission disk | 48 MB |

Each disk fills up on its own: one being full says nothing about the others.
`df -h` prints one line per disk, so you can see this for yourself:

```bash
df -h / /srv/data /srv/spool
```

## Two separate problems

Debarshi's two complaints look alike — both end in "No space left on device" —
but they are **two unrelated faults on two different disks**, with different
causes. Fixing one does nothing for the other. Tackle them in either order;
each is marked on its own.

| | Disk | What is wrong | Marks |
|---|---|---|---|
| **(a)** | `/srv/data` | genuinely full, and the visible files do not account for it | 12 |
| **(b)** | `/srv/spool` | refuses new files, although `df -h` shows free space | 4 |

---

## (a) `/srv/data` is full

### What exactly is the problem

`/srv/data` is at 100%, and the files you can see there do not add up to the
space reported as used.

### How to reproduce it

```bash
df -h /srv/data                         # 100% used
sudo du -sh /srv/data                   # much smaller than df says is in use
```

The second line is the thing Debarshi noticed, and it is worth taking seriously.

### What to fix

**Bring `/srv/data` back to under 10% used** — the `Use%` column of
`df -h /srv/data`.

Reclaiming space is the job; finding *what* is holding it is the harder half.
Look at how much space `df` says is in use, then at how much `du` can actually
account for, and treat any difference between those two numbers as something
you still have to explain. There is more than one reason this disk is full:
freeing the largest obvious files will help, but will not get you to 10% on its
own. Before you delete anything, check whether it is safe to delete — the
archive directory carries a note saying what has already been copied elsewhere.

### How to check you have fixed it

```bash
df -h /srv/data                         # Use% under 10%
ls /srv/data/current                    # five survey-block CSV files, still there
```

---

## (b) `/srv/spool` refuses new files

### What exactly is the problem

New files cannot be created on `/srv/spool`, **even though `df -h` reports free
space** on it. Something other than free space has run out. This has nothing to
do with `/srv/data`.

### How to reproduce it

```bash
df -h /srv/spool                        # shows space free
touch /srv/spool/incoming/testjob       # "No space left on device"
```

### What to fix

**Make `/srv/spool` able to accept new files again.**

This disk is not short of space — `df -h` will keep telling you it has room, and
freeing bytes will not help. A filesystem can run out of more than one kind of
resource, and `df` has another mode that reports the other one. Find what has
run out, find what consumed it, and clear that. `/srv/spool/queue/README`
explains what the directory is for and should stay.

Then, in `~/FIXLOG.md`, explain in two or three sentences why `/srv/spool`
reported **"No space left on device"** while `df -h` showed free space: name the
resource that actually ran out, what consumed it, and why the error says "space"
when space was not the problem. This is marked on whether you understood the
mechanism, not on length.

### How to check you have fixed it

```bash
touch /srv/spool/incoming/testjob && echo OK && rm /srv/spool/incoming/testjob
```

---

## Constraints — these apply to both parts, and are marked

- **Nothing under `/srv/data/current` may be deleted or changed.** That is live
  survey data with no second copy on this machine.
- Do not reformat, recreate, resize or unmount either disk.
- `/srv/data/archive/README.txt` says what is and is not safe to remove there.
  Read it before deleting anything.
- Rebooting clears one of these faults. On a real file server at 11am you would
  not have that option, so treat it as unavailable here too.

## Notes

- When two tools disagree about the same disk, both are usually telling the
  truth about different things.
- Worth knowing about: `df -h`, `df -i`, `du -xh --max-depth=1`, `lsof`,
  `findmnt`, `systemctl`, `journalctl`. Not all of them are relevant.
- Record symptom, cause, change and verification in `~/FIXLOG.md`, one entry
  for each part.
