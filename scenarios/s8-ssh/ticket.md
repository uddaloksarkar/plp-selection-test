# Q3 — Cannot log in to the ACMU lab server · 10 marks

*Reported by Debarshi, research scholar:*

> "I am supposed to log in to the lab server as `acmusrv`. It worked last week.
> Now it just says *Permission denied*, and then asks me for a password I was
> never given. I have not touched anything since."

`ssh acmulab` should log you in to the account `acmusrv` on the lab server
using the key `~/.ssh/id_acmu`, **without a password**. Two things are wrong,
and they produce the **same message**: `Permission denied (publickey)`.
Identify both of them.

## How to reproduce it

```bash
ssh acmulab
cat ~/.ssh/config
ls -l ~/.ssh/
```

## What to fix · 10 marks

**1.** **Make the `acmulab` alias use the right key.** The `~/.ssh/config` file
is corrupted. Fix it so that `ssh acmulab` succeeds without a password prompt.

**2.** **Make the key usable.** Find out why ssh still refuses to use the key,
and fix it.

## How to check you have fixed it

```bash
ssh acmulab whoami                      # prints: acmusrv
ls -l ~/.ssh/id_acmu                    # -rw------- (0600)
```

If that prints `acmusrv` without asking you for anything, the key is doing the
work.
