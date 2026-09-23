# TICKET #4451 — Cannot log in to the ACMU lab server

**Raised by:** Debarshi Roy, research scholar · **Priority:** Medium
**Assigned:** you · **Host:** this machine

> "I'm supposed to log in to the lab server as `acmusrv` with the key the
> systems group set up for me, and run the nightly extract. It worked last
> week. Now it just says *Permission denied*, and then asks me for a password
> I was never given. I haven't touched anything since."

## 1. What exactly is the problem

`ssh acmulab` should log you in to the account `acmusrv` on the lab server
using the key `~/.ssh/id_acmu`, **without a password** — that account has no
password to type.

Two things are wrong, and they produce the **same message**:
`Permission denied (publickey)`. The first means the key is never offered at
all; the second means it is offered and then refused. Fixing one and trying
again will look like nothing happened, so work out which you are looking at
before you change anything.

## 2. How to reproduce it

```bash
ssh acmulab
```

Then ask the useful question — *did ssh even try the key?*

```bash
ssh -v acmulab 2>&1 | grep -i 'identity file\|offering\|publickey'
cat ~/.ssh/config
ls -l ~/.ssh/
```

## 3. What to fix

**3.1 Make the `acmulab` alias use the right key.** One line is missing from
its block in `~/.ssh/config`; everything else in that block is correct.

**3.2 Make the key usable.** SSH refuses to use a private key that other people
on the machine could read, and says so plainly under `-v`.

When both are done, `ssh acmulab` logs you straight in as `acmusrv` with no
password prompt.

## 4. How to check you have fixed it

```bash
ssh -o BatchMode=yes acmulab whoami     # prints: acmusrv
```

`BatchMode=yes` forbids any password prompt, so if this prints `acmusrv` the
key really is doing the work.

```bash
ls -l ~/.ssh/id_acmu                    # -rw------- (0600)
grep -i identityfile ~/.ssh/config
```

## Constraints — these are marked

- **Do not give `acmusrv` a password**, and do not enable password
  authentication. The account is key-only by policy. A password makes the
  symptom go away without fixing anything, and **loses marks**.
- No `chmod 777` on anything under `.ssh`.

## Notes

- `ssh -v` is the whole diagnosis here. It prints which key files it considered,
  which it offered, and what the server said. Read it before editing anything.
- *Permission denied* means something answered and said no — quite different
  from *Connection refused*, which means nothing was listening at all.
- The key pair itself is fine. Nothing needs regenerating, and nothing on the
  server side needs changing.
- Record symptom, cause, change and verification in `~/FIXLOG.md`.
