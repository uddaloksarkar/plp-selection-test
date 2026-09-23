# S7 — Reverse SSH tunnel (10 marks)

| id | part | marks | what it checks |
|---|---|---|---|
| s7.keys | (a) | 5 | `tunnel`'s home, `.ssh` and `authorized_keys` not group/world-writable, owned by tunnel or root, labbox's key still present |
| s7.target | (b) | 5 | the unit's `-R` forwards `8080` to `localhost:8888` (or `127.0.0.1:8888`) |
| s7.penstrict | | −4 | `StrictModes no` in effect for `tunnel` |
| s7.penexpose | | −4 | labbox's dashboard reachable directly at `10.20.0.2:8888` |
| s7.penpass | | −3 | the `tunnel` account has a password and sshd would accept it |

## Faults injected
1. `/home/tunnel/.ssh/authorized_keys` → mode `0666`. sshd logs *"Authentication refused: bad ownership or modes for file …"*; the tunnel logs *"Permission denied (publickey,password)"* and restarts every 5 s. (`0664` is **not** enough on Ubuntu: its `user-group-modes` patch allows group-write when the group is the user's private group.)
2. `lab-tunnel.service`: `-R 0.0.0.0:8080:localhost:8889`. The dashboard is on `8888`. Visible statically (`sudo labbox ss -tlnp` vs `systemctl cat lab-tunnel`) and, once (1) is fixed, as *"connect_to localhost port 8889: failed"* in the tunnel's log on every request.

Each check tests its own layer only — a file mode, a unit line, an sshd setting —
so (a)–(c) are marked independently and in any order (verified: each fix alone
flips only its own check; all three give 16/16 in any order). The end-to-end
`curl` in the ticket is for the candidate's confidence and is not marked.

## What separates a strong candidate
- Reads **both** ends' logs for (a): the client only says "denied"; the server says why.
- Explains whose `localhost` is meant in `-R …:localhost:8888` (labbox's).
- Uses `ss -tlnp` on the gateway for (c) and notices `127.0.0.1:8080` — the tunnel is *up*, which is what makes this fault hard.
- Runs `sshd -t` before every reload. Uses `sshd -T -C user=tunnel,…` to see the effective setting.
- Does not reach for `StrictModes no`, and does not "solve" it by opening labbox.

## Viva follow-ups
- "Draw the tunnel. Which end listens, which connects, which way does a request travel?"
- "Why does sshd care who can *write* `authorized_keys`?"
- "`curl localhost:8080` worked on the gateway. Why not from outside?"
- "Campus IT blocks inbound to labbox. Is this tunnel a hole in that policy? Who should approve it?"
