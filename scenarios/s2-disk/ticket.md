# TICKET #4419 — "Disk full" on the lab file server

**Raised by:** Anita Roy, research scholar · **Priority:** High
**Assigned:** you · **Host:** this machine · **Raised:** 06:55 today

> "Three of us have hit this since this morning.
>
> 1. The reporting log stopped updating some time before 07:00.
> 2. I can't copy anything into `/srv/data` — it says the disk is full.
> 3. Submitting a job into `/srv/spool` *also* says the disk is full, but
>    `df -h` shows that one has plenty of space left. That part makes no sense
>    to me.
>
> I haven't deleted anything, I didn't want to make it worse."

## 1. What exactly is the problem

Two different storage faults, on two different filesystems:

- **`/srv/data`** is genuinely full. The reporting daemon can no longer write to
  its log.
- **`/srv/spool`** refuses to create new files **even though `df` reports free
  space**. Something other than free bytes has run out.

## 2. How to reproduce it

```bash
df -h /srv/data
tail -1 /srv/data/logs/reportd.log      # last line is hours old
```

```bash
df -h /srv/spool                        # shows space free
touch /srv/spool/incoming/testjob       # "No space left on device"
```

And the thing Anita noticed, which is worth taking seriously:

```bash
sudo du -sh /srv/data                   # much smaller than df says is in use
```

## 3. What to fix

Four things. Each is assessed separately, so do as many as you can — an
incomplete ticket still earns the parts you got right.

**3.1 Bring `/srv/data` back to under 10% used.**

"Under 10%" means the `Use%` column of `df -h /srv/data`. Reclaiming space is
the job; finding *what* is holding it is the harder half. Look at how much space
`df` says is in use, then at how much `du` can actually account for, and treat
any difference between those two numbers as something you still have to explain.
Freeing the largest obvious files will help but will not get you to 10% on its
own. Before you delete anything, check whether it is safe to delete — the
archive directory carries a note saying what has already been copied elsewhere.

**3.2 Get the reporting daemon writing to its log again.**

The service `reportd` is running, but its writes have been failing because the
filesystem was full. Once space exists, confirm it has actually resumed rather
than assuming: look at the last line of `/srv/data/logs/reportd.log` and check
its timestamp is current, not hours old. If it has not picked up by itself,
restarting the service is reasonable — say so in your FIXLOG if you do.

**3.3 Make `/srv/spool` able to accept new files again.**

This is a *separate* filesystem with a *separate* fault, and it is not short of
space — `df -h` will keep telling you it has room. Freeing bytes there will not
help. A filesystem can exhaust more than one kind of resource, and `df` has
another mode that reports the other one. Find what has run out, find what
consumed it, and clear that. `/srv/spool/queue/README` explains what the
directory is for and should stay.

**3.4 Write the explanation in `~/FIXLOG.md`.**

Specifically: why did `/srv/spool` report **"No space left on device"** while
`df` showed free space? Two or three sentences naming the actual resource that
ran out, what consumed it, and why the error message says "space" when space was
not the problem. This is marked on whether you understood the mechanism, not on
length.

## 4. How to check you have fixed it

Run these. All four should look right before you move on.

```bash
df -h /srv/data                         # Use% under 10%
```
```bash
sudo systemctl restart reportd; sleep 5
tail -1 /srv/data/logs/reportd.log      # timestamp within the last few seconds
date                                    # compare
```
```bash
touch /srv/spool/incoming/testjob && echo OK && rm /srv/spool/incoming/testjob
```
```bash
ls /srv/data/current                    # five survey-block CSV files, still there
```

## Constraints — these are marked

- **Nothing under `/srv/data/current` may be deleted or changed.** That is live
  survey data with no second copy on this machine.
- Do not reformat, recreate, resize or unmount either filesystem.
- `/srv/data/archive/README.txt` says what is and is not safe to remove there.
  Read it before deleting anything.

## Notes

- There is more than one reason `/srv/data` is full. Freeing the obvious thing
  will not get you under 10% on its own.
- When two tools disagree about the same filesystem, both are usually telling
  the truth about different things.
- Rebooting clears one of these faults. On a real file server at 11am you would
  not have that option, so treat it as unavailable here too.
- Worth knowing about: `df -h`, `df -i`, `du -xh --max-depth=1`, `lsof`,
  `systemctl`, `journalctl`. Not all of them are relevant.
- Record symptom, cause, change and verification in `~/FIXLOG.md`.
