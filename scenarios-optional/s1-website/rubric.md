# S1 — Website unavailable (18 marks)

| id | marks | what it checks |
|---|---|---|
| s1.page | 7 | vhost serves the real page on :80 |
| s1.subdir | 2 | recursive perms fixed, not just the top file |
| s1.conftest | 3 | `nginx -t` clean (the duplicate `default_server` removed) |
| s1.active | 3 | service running |
| s1.enabled | 3 | re-enabled for boot |
| s1.pen777 / s1.penww | −4 each | "fixed" it with `chmod 777` |
| s1.penroot | −5 | made nginx run as root |

## Faults injected
1. `/etc/nginx/sites-enabled/zz-legacy.conf` declares a second `listen 80 default_server` → `nginx -t` fails with *a duplicate default server*.
2. `/srv/www/acmu` chowned to `root:root`, mode `0700` → 403 once nginx starts.
3. `nginx` stopped **and** disabled.

## What separates a strong candidate
- Reads `nginx -t` / `journalctl -u nginx` **before** touching anything.
- Fixes fault 2 by restoring `www-data` ownership + `0755`, **not** by `chmod -R 777` and **not** by making nginx run as root.
- Notices `disable` as a separate defect from `stop` — i.e. thinks about reboot.
- Does not delete `zz-legacy.conf` silently without noting the "do not delete" comment; the right move is to disable the symlink and flag it to the owner. Either action scores, but the viva should probe the reasoning.

## Viva follow-ups
- "Show me how you proved the fix, not just that the page loads."
- "The legacy file said *do not delete*. What did you actually do and who would you tell?"
- "If the page had loaded for you but not for the department, where would you look next?"
