# TICKET #4423 — Shared project folder unusable

**Raised by:** Anita Roy, on behalf of the Statistics Lab group · **Priority:** Medium-High
**Assigned:** you · **Host:** this machine

> "Four things, all in `/srv/projects/statlab/`:
>
> - Bikram can't save anything into `shared/`, and can't open `notes.md` at all.
>   He could last month.
> - When I create a file in there, the others can't edit it. It keeps coming out
>   belonging to my own personal group instead of the project group.
> - `sudo systemctl restart reportd` used to work for all of us. Now it's refused.
> - Chandan from the internal audit cell needs to *read* that folder for the
>   annual review. He can't see anything."

## 1. What exactly is the problem

`/srv/projects/statlab/` is a shared area for the `statlab` group. Several
things about it have been changed:

- A group member cannot write there, or read a shared file.
- New files created there do not come out belonging to the group, so nobody else
  can edit them.
- A delegated `sudo` right no longer does what it was meant to do.
- The auditor has no access at all.

## 2. How to reproduce it

```bash
sudo -u bikram touch /srv/projects/statlab/shared/test     # Permission denied
sudo -u bikram cat /srv/projects/statlab/shared/notes.md   # Permission denied
```
```bash
sudo -u anita sudo -n systemctl restart reportd            # refused
```
```bash
sudo -u chandan cat /srv/projects/statlab/shared/notes.md  # Permission denied
```

To see the current state:

```bash
stat -c '%a %U:%G %n' /srv/projects/statlab /srv/projects/statlab/shared/notes.md
id bikram
getfacl /srv/projects/statlab
sudo cat /etc/sudoers.d/statlab
```

## 3. What to fix

1. Everyone in the `statlab` group can read **and write** everything under
   `/srv/projects/statlab/`.
2. A file created there by one member ends up usable by the whole group.
3. `notes.md` is a shared file again, not one person's private file.
4. Members of `statlab` — and only them — can run
   `sudo -n systemctl restart reportd` without being asked for a password.
5. **Chandan can read** that tree.

## 4. How to check you have fixed it

Test as the affected users, not as root. Every line should behave as noted.

```bash
sudo -u bikram touch /srv/projects/statlab/shared/t1 && echo "write OK"
stat -c '%U:%G' /srv/projects/statlab/shared/t1     # group must be: statlab
sudo rm -f /srv/projects/statlab/shared/t1
```
```bash
sudo -u bikram cat /srv/projects/statlab/shared/notes.md >/dev/null && echo "read OK"
```
```bash
sudo -u anita sudo -n systemctl restart reportd && echo "sudo OK"
```
```bash
sudo -u chandan cat /srv/projects/statlab/shared/notes.md >/dev/null && echo "auditor read OK"
sudo -u chandan touch /srv/projects/statlab/shared/t2 && echo "PROBLEM: auditor can write"
```

The second line of the first block is the one people miss. If the group comes
out as anything other than `statlab`, complaint two is not fixed yet.

## Constraints — these are marked

- **Chandan must not be put into the `statlab` group.** Audit policy forbids
  putting auditors into the groups they audit. He must be able to read and must
  **not** be able to write.
- No `chmod 777`, anywhere. This is a multi-user machine.
- Do not change anyone's login shell, password or home directory.

## Notes

- One of these faults is about which **bits are set on a directory**, not about
  who owns it. A directory can carry more than the nine permission bits you see
  first.
- Group membership changes do not affect a shell that is already open.
- Edit anything under `/etc/sudoers.d/` with `visudo -f`, not a plain editor.
- Worth knowing about: `stat`, `chmod`, `chown`, `id`, `groups`, `gpasswd`,
  `getfacl`, `setfacl`, `visudo`. Not all of them are relevant.
- Record symptom, cause, change and verification in `~/FIXLOG.md`.
