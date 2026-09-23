# S3 — User permissions (16 marks)

| id | marks | what it checks |
|---|---|---|
| s3.dirmode | 3 | setgid bit restored, group write, not world-writable |
| s3.dirgroup | 1 | group ownership is `acmu` |
| s3.member | 2 | `buddhadev` re-added to the group |
| s3.groupwrite | 4 | a member (arnab) can create a file **and it inherits group `acmu`** |
| s3.notes | 2 | `notes.md` is group `acmu`, group read-write |
| s3.sudo | 2 | sudoers drop-in points at the right unit again |
| s3.sudosyn | 1 | the drop-in still parses under `visudo -c` |
| s3.aclread | 1 | auditor reads via ACL |
| s3.penacl | −4 | auditor can write (over-granted) |
| s3.pengrp | −4 | auditor added to the group — explicitly forbidden |
| s3.pen777 | −5 | world-writable anything |

## Faults injected
1. `chmod 0750` on the tree — drops **both** setgid and group write. The "files come out owned by my personal group" complaint is the setgid symptom; most candidates fix only the write bit.
2. `buddhadev` removed from `acmu`. Note: fixing this needs a **re-login** to take effect for an interactive session — `id buddhadev` shows it immediately but buddhadev's existing shell does not. Good viva material.
3. `notes.md` → `arnab:arnab 0600`.
4. sudoers drop-in silently restarts **nginx** instead of **reportd**. Syntax is valid, so `visudo -c` is clean — only reading the rule finds it.
5. ACLs wiped with `setfacl -b`.

Each check tests one fault, so the ticket's parts (a)–(e) are marked
independently: `s3.groupwrite` runs as arnab, who stays a member, and
`s3.notes` reads the file's group and mode rather than testing as buddhadev. The
baseline gives "other" no access (`2770`, `0660`), so the auditor can only read
through his ACL — fixing `notes.md` does not quietly fix part (e) as well.

| Part | Fault | Checks | Marks |
|---|---|---|---|
| (a) | 2 | s3.member | 2 |
| (b) | 1 | s3.dirmode, s3.dirgroup, s3.groupwrite | 8 |
| (c) | 3 | s3.notes | 2 |
| (d) | 4 | s3.sudo, s3.sudosyn | 4 |
| (e) | 5 | s3.aclread | 1 |

## What separates a strong candidate
- Gets the **setgid** bit, not just `g+w`. This is the single best discriminator in the whole paper.
- Uses `setfacl -m u:chandrima:rX` **plus** a default ACL (`-d`) so new files stay readable — and resists the temptation to just add him to the group.
- Knows that group membership changes need a new login session, and says so.
- Uses `sudo -u buddhadev` / `sudo -u chandrima` to test rather than declaring victory from root.
- Edits `/etc/sudoers.d/acmu` with `visudo -f`, not `vim`.

## Viva follow-ups
- "What does the `2` in `2770` do, and what breaks without it?"
- "Why an ACL for the auditor rather than the group? What is the default ACL for?"
- "You added buddhadev back to the group; his shell still says permission denied. Why?"
- "How would you set this up for ten more project groups without doing it by hand each time?"
