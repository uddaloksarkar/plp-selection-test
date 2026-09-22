#!/usr/bin/env bash
# Faults: (1) setgid + group write stripped from the shared tree
#         (2) bikram removed from the group
#         (3) notes.md re-owned to a single user, mode 0600
#         (4) sudo rule points at the wrong unit (valid syntax, wrong effect)
#         (5) auditor ACLs wiped
set -euo pipefail
[ -f /etc/plp-exam-vm ] || { echo "not an exam VM" >&2; exit 3; }

setfacl -R -b /srv/projects/statlab
# GNU chmod will SET but not CLEAR setgid on a directory from a numeric mode,
# so 'chmod 0755' alone leaves the 2 in place. Clear it symbolically.
chmod 0755 /srv/projects/statlab
chmod 0755 /srv/projects/statlab/shared
chmod g-s  /srv/projects/statlab
chmod g-s  /srv/projects/statlab/shared
gpasswd -d bikram statlab >/dev/null
chown anita:anita /srv/projects/statlab/shared/notes.md
chmod 0600 /srv/projects/statlab/shared/notes.md
cat > /etc/sudoers.d/statlab <<'SUDO'
# Statistics Lab: members may restart the reporting daemon themselves.
# edited 2026-01-12 during the web server migration
%statlab ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx
SUDO
chmod 0440 /etc/sudoers.d/statlab
echo "s3 armed"
