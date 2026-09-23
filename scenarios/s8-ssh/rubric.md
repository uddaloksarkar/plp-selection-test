# S8 — SSH key login (10 marks)

| id | marks | what it checks |
|---|---|---|
| s8.identity | 2 | `IdentityFile … id_acmu` restored to the `acmulab` block |
| s8.keyperm | 2 | private key back to `0600` |
| s8.connect | 6 | `ssh -o BatchMode=yes acmulab whoami` → `acmusrv` |
| s8.penpw | −3 | gave `acmusrv` a password to dodge key authentication |
| s8.pen777 | −3 | world-writable anything under `.ssh` |

Three checks rather than two, so a candidate who fixes only one fault still
banks the mark for it.

## Faults injected

1. The `IdentityFile` line is deleted from the `acmulab` block in
   `/home/candidate/.ssh/config`. With `IdentitiesOnly yes` also in that block,
   ssh offers **no key at all**.
2. `/home/candidate/.ssh/id_acmu` is `0644`. ssh refuses a private key others
   could read: *UNPROTECTED PRIVATE KEY FILE*.

Both are in the candidate's own home directory, so nothing they do here can
lock them out of their own session.

## What separates a strong candidate

- **Reads `ssh -v`.** The two faults give an identical one-line error; only the
  verbose output distinguishes "no key offered" from "key offered and refused".
  A candidate who fixes 3.1, re-runs, sees the same message and concludes they
  achieved nothing has not looked.
- Fixes the mode rather than working around it — no `chmod 777`, no password on
  the account, no touching sshd.
- Notices that nothing server-side is wrong and leaves it alone.

## Viva follow-ups

- "Both faults printed the same error. How did you tell them apart?"
- "Why does ssh care what mode your private key is? Whose problem is it?"
- "What would `Connection refused` have meant instead, and where would you have
  looked?"
- "You have ten machines to set this up on tomorrow. What do you do differently?"
