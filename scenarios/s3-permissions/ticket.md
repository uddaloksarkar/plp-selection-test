# TICKET #4423 — Shared project folder unusable

**Raised by:** Arnab Basu, on behalf of the ACMU Lab group · **Priority:** Medium-High
**Assigned:** you · **Host:** this machine

> "Three things, all in `/srv/projects/acmu/`:
>
> - Buddhadev can't save anything into `shared/`, and can't open `notes.md` at all.
>   He could last month.
> - `sudo systemctl restart reportd` used to work for all of us. Now it's refused.
> - Chandrima from the internal audit cell needs to *read* that folder for the
>   annual review. He can't see anything."

## Background: who is who

| User | Role | Should be able to |
|---|---|---|
| `arnab` | member of the `acmu` group | read and write everything in the folder |
| `buddhadev` | member of the `acmu` group | read and write everything in the folder |
| `chandrima` | internal auditor, **not** a member | read everything, write nothing |

`/srv/projects/acmu/` (and `shared/` inside it) belongs to the `acmu`
group. Anyone who is not a member or the auditor should have no access at all.

## Five separate problems

Arnab's three complaints overlap, but underneath them are **five independent
faults**, each with its own cause and its own fix. Fixing one does nothing for
the others, and each is marked on its own. Tackle them in any order.

| | What is wrong | Marks |
|---|---|---|
| **(a)** | Buddhadev is no longer in the `acmu` group | 3 |
| **(b)** | The shared folder does not let the group write | 7 |
| **(c)** | `notes.md` has become one person's private file | 2 |
| **(d)** | The group's `sudo` right restarts the wrong service | 3 |
| **(e)** | The auditor has lost his read access | 1 |

Buddhadev's complaint needs (a), (b) and (c) all fixed before it goes away
completely. That is why the checks below test each part on its own; the final
section tests them together.

To see the current state of everything at once:

```bash
stat -c '%a %U:%G %n' /srv/projects/acmu /srv/projects/acmu/shared \
                      /srv/projects/acmu/shared/notes.md
id buddhadev
getfacl /srv/projects/acmu/shared
sudo cat /etc/sudoers.d/acmu
```

---

## (a) Buddhadev is no longer in the group

**Problem.** Buddhadev has been removed from `acmu`, so the folder treats him as
an outsider.

**Reproduce.**
```bash
id buddhadev                          # acmu is missing from the list
```

**Fix.** Put Buddhadev back in the `acmu` group, without changing any of his
other groups.

**Check.**
```bash
id -nG buddhadev | grep -qw acmu && echo "buddhadev is a member"
```

---

## (b) The shared folder does not let the group write

**Problem.** Members of `acmu` cannot create files in the folder at all. This
is about the **permission bits on the two directories**,
`/srv/projects/acmu` and `shared/`.

**Reproduce.** Arnab is still a member, so test as her:
```bash
sudo -u arnab touch /srv/projects/acmu/shared/t1     # Permission denied
stat -c '%a %U:%G %n' /srv/projects/acmu /srv/projects/acmu/shared
```

**Fix.** Both directories must let the `acmu` group read, write and enter them,
and give everyone else no write access. Remember that a directory needs its
execute bit before anyone can go into it at all.

**Check.**
```bash
sudo -u arnab touch /srv/projects/acmu/shared/t1 && echo "write OK"
sudo rm -f /srv/projects/acmu/shared/t1
stat -c '%a %U:%G %n' /srv/projects/acmu /srv/projects/acmu/shared
```

---

## (c) `notes.md` has become private

**Problem.** `shared/notes.md` is the group's shared working file, but it has
been changed to belong to one person, readable only by her.

**Reproduce.**
```bash
stat -c '%a %U:%G' /srv/projects/acmu/shared/notes.md   # 600 arnab:arnab
```

**Fix.** Make it a group file again: group `acmu`, readable and writable by
the group, no access for anyone else.

**Check.**
```bash
stat -c '%a %G' /srv/projects/acmu/shared/notes.md      # 660 acmu
```

---

## (d) The group's `sudo` right is broken

**Problem.** Members of `acmu` are meant to be able to restart the reporting
service `reportd` themselves, without a password. That right is defined in
`/etc/sudoers.d/acmu`, and it no longer does what it was meant to.

**Reproduce.**
```bash
sudo -u arnab sudo -n systemctl restart reportd            # refused
sudo cat /etc/sudoers.d/acmu
```

**Fix.** Members of `acmu` — and only them — can run
`sudo -n systemctl restart reportd` without being asked for a password.
Edit the file with `sudo visudo -f /etc/sudoers.d/acmu`, not a plain editor.

**Check.**
```bash
sudo -u arnab sudo -n systemctl restart reportd && echo "sudo OK"
sudo visudo -cf /etc/sudoers.d/acmu                     # parsed OK
```

---

## (e) The auditor cannot read the folder

**Problem.** Chandrima must be able to read the whole tree for the audit, but is
not a member of `acmu` and must not become one. His access used to come from
per-user entries on the files themselves, and those have been wiped.

**Reproduce.**
```bash
sudo -u chandrima ls  /srv/projects/acmu/shared            # Permission denied
getfacl /srv/projects/acmu/shared                        # no entry for chandrima
```

**Fix.** Give Chandrima read-only access to everything under
`/srv/projects/acmu/`, including files created there in future — **without**
adding him to the group.

**Check.**
```bash
sudo -u chandrima cat /srv/projects/acmu/shared/notes.md >/dev/null && echo "auditor read OK"
sudo -u chandrima touch /srv/projects/acmu/shared/t2 && echo "PROBLEM: auditor can write"
```
The second line must print nothing but an error.

---

## When all five are done

Buddhadev's original complaint should be gone:

```bash
sudo -u buddhadev touch /srv/projects/acmu/shared/t3 && echo "buddhadev write OK"
stat -c '%U:%G' /srv/projects/acmu/shared/t3             # buddhadev:acmu
sudo rm -f /srv/projects/acmu/shared/t3
sudo -u buddhadev cat /srv/projects/acmu/shared/notes.md >/dev/null && echo "buddhadev read OK"
```

## Constraints — these apply to every part, and are marked

- **Chandrima must not be put into the `acmu` group.** Audit policy forbids
  putting auditors into the groups they audit. He must be able to read and must
  **not** be able to write.
- No `chmod 777`, anywhere. This is a multi-user machine.
- Do not change anyone's login shell, password or home directory.

## Notes

- Group membership changes do not affect a shell that is already open.
  `sudo -u <user> …` starts a fresh one, so the checks above see them at once.
- Test as the affected users, not as root: root can read and write everything,
  so a check run as root proves nothing.
- Worth knowing about: `stat`, `chmod`, `chown`, `id`, `groups`, `gpasswd`,
  `getfacl`, `setfacl`, `visudo`. Not all of them are relevant.
- Record symptom, cause, change and verification in `~/FIXLOG.md`, one entry
  for each part.
