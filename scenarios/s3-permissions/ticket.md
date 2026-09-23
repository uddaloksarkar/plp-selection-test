# Q2 — Shared project folder unusable · 16 marks

*Reported for the ACMU Lab group:*

> "Buddhadev cannot save anything into `shared/`, which he could last month.
> And Chandrima from the internal audit cell needs to *read* that folder for
> the annual review, and cannot see anything at all."

## Background: who is who

`/srv/projects/acmu/` (and `shared/` inside it) belongs to the `acmu` group.
Anyone who is neither a member nor the auditor should have no access at all.

| account | | should be able to |
|---|---|---|
| `arnab` | member of `acmu` | read and write everything |
| `buddhadev` | member of `acmu` | read and write everything |
| `chandrima` | auditor, **not** a member | read everything, write nothing |

To see the current state:

```bash
cd /srv/projects/acmu
stat -c '%a %U:%G %n' . shared shared/notes.md
id buddhadev
getfacl /srv/projects/acmu/shared
```

Underneath the two complaints are **three independent faults**, each with its
own cause and fix, each marked on its own. Take them in any order.

**Test as the users named, not as root.** Root can do everything, so a check
run as root proves nothing.

| | What is wrong | Marks |
|---|---|---|
| **(a)** | Buddhadev is no longer in the `acmu` group | 5 |
| **(b)** | The shared folder does not let the group write | 8 |
| **(c)** | The auditor cannot read the folder | 3 |

---

## (a) Buddhadev is no longer in the `acmu` group · 5 marks

**Reproduce.** Check `id buddhadev` — `acmu` is missing.

**Fix.** Put him back, without disturbing his other groups.

**Check.** Keep checking with `id buddhadev` until it shows `acmu` again.

---

## (b) The shared folder does not let the group write · 8 marks

Members of `acmu` cannot create files in the folder at all. Arnab is still a
member, so test as arnab:

```bash
sudo -u arnab touch /srv/projects/acmu/shared/t1     # Permission denied
stat -c '%a %U:%G %n' /srv/projects/acmu /srv/projects/acmu/shared
```

**Fix.** Both directories must let the `acmu` group read, write and enter them,
and give everyone else no write access.

**Check.**
```bash
sudo -u arnab touch /srv/projects/acmu/shared/t1 && echo "write OK"
sudo rm -f /srv/projects/acmu/shared/t1
```

---

## (c) The auditor cannot read the folder · 3 marks

**Fix.** Grant read-only access to everything under `/srv/projects/acmu/`,
including files created there in future, and do it **without** adding
chandrima to the group.

**Check.**
```bash
sudo -u chandrima cat /srv/projects/acmu/shared/notes.md   # must work
sudo -u chandrima touch /srv/projects/acmu/shared/t2       # must FAIL
```

---

## When all three are done

Buddhadev's complaint needs (a) and (b) together:

```bash
sudo -u buddhadev touch /srv/projects/acmu/shared/t3        # must work
sudo -u buddhadev cat /srv/projects/acmu/shared/notes.md    # must work
```

## Constraints

- **Chandrima must not be put into the `acmu` group.** Audit policy forbids
  putting auditors into the groups they audit: read everything, write nothing.
- No `chmod 777`, anywhere. This is a multi-user machine.
