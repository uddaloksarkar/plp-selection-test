#!/usr/bin/env bash
# Faults: (1) setgid + group write stripped from the shared tree (0750)
#         (2) buddhadev removed from the group
#         (3) notes.md re-owned to a single user, mode 0600
#         (5) auditor ACLs wiped
set -euo pipefail
[ -f /etc/plp-exam-vm ] || { echo "not an exam VM" >&2; exit 3; }

setfacl -R -b /srv/projects/acmu
# GNU chmod will SET but not CLEAR setgid on a directory from a numeric mode,
# so 'chmod 0750' alone leaves the 2 in place. Clear it symbolically.
chmod 0750 /srv/projects/acmu
chmod 0750 /srv/projects/acmu/shared
chmod g-s  /srv/projects/acmu
chmod g-s  /srv/projects/acmu/shared
gpasswd -d buddhadev acmu >/dev/null
chown arnab:arnab /srv/projects/acmu/shared/notes.md
chmod 0600 /srv/projects/acmu/shared/notes.md
echo "s3 armed"
