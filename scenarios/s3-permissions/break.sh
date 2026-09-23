#!/usr/bin/env bash
# Faults: (1) group write stripped from the shared tree (0750)
#         (2) buddhadev removed from the group
#         (3) auditor ACLs wiped
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
echo "s3 armed"
