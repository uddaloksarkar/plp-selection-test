# S3 — User permissions (18 marks)

| id | marks | what it checks |
|---|---|---|
| s3.dirmode | 3 | setgid bit restored, group write, not world-writable |
| s3.dirgroup | 1 | group ownership is `statlab` |
| s3.member | 3 | `bikram` re-added to the group |
| s3.groupwrite | 4 | bikram can create a file **and it inherits group `statlab`** |
| s3.notes | 2 | `notes.md` ownership/mode fixed |
| s3.sudo | 3 | sudoers drop-in points at the right unit again |
| s3.sudosyn | 1 | the drop-in still parses under `visudo -c` |
| s3.aclread | 1 | auditor reads via ACL |
| s3.penacl | −4 | auditor can write (over-granted) |
| s3.pengrp | −4 | auditor added to the group — explicitly forbidden |
| s3.pen777 | −5 | world-writable anything |

## Faults injected
1. `chmod 0755` on the tree — drops **both** setgid and group write. The "files come out owned by my personal group" complaint is the setgid symptom; most candidates fix only the write bit.
2. `bikram` removed from `statlab`. Note: fixing this needs a **re-login** to take effect for an interactive session — `id bikram` shows it immediately but bikram's existing shell does not. Good viva material.
3. `notes.md` → `anita:anita 0600`.
4. sudoers drop-in silently restarts **nginx** instead of **reportd**. Syntax is valid, so `visudo -c` is clean — only reading the rule finds it.
5. ACLs wiped with `setfacl -b`.

## What separates a strong candidate
- Gets the **setgid** bit, not just `g+w`. This is the single best discriminator in the whole paper.
- Uses `setfacl -m u:chandan:rX` **plus** a default ACL (`-d`) so new files stay readable — and resists the temptation to just add him to the group.
- Knows that group membership changes need a new login session, and says so.
- Uses `sudo -u bikram` / `sudo -u chandan` to test rather than declaring victory from root.
- Edits `/etc/sudoers.d/statlab` with `visudo -f`, not `vim`.

## Viva follow-ups
- "What does the `2` in `2775` do, and what breaks without it?"
- "Why an ACL for the auditor rather than the group? What is the default ACL for?"
- "You added bikram back to the group; his shell still says permission denied. Why?"
- "How would you set this up for ten more project groups without doing it by hand each time?"
