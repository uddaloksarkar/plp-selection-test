#!/usr/bin/env bash
# Baseline: a shared group project area + a delegated sudo rule + a read-only auditor
set -euo pipefail
getent group statlab >/dev/null || groupadd statlab
for u in anita bikram chandan; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
done
gpasswd -M anita,bikram statlab >/dev/null      # chandan is deliberately NOT a member

install -d -m 0755 /srv/projects
install -d /srv/projects/statlab/shared
chown -R root:statlab /srv/projects/statlab
chmod 2775 /srv/projects/statlab
chmod 2775 /srv/projects/statlab/shared

cat > /srv/projects/statlab/shared/notes.md <<'MD'
# Sampling notes — shared working file
Everyone in the statlab group edits this; the internal auditor reads it.
MD
chown root:statlab /srv/projects/statlab/shared/notes.md
chmod 0664 /srv/projects/statlab/shared/notes.md

# read-only auditor access, without putting him in the group
setfacl -R  -m u:chandan:rX /srv/projects/statlab
setfacl -d -m u:chandan:rX /srv/projects/statlab
setfacl -d -m u:chandan:rX /srv/projects/statlab/shared

# delegated restart right for the group
cat > /etc/sudoers.d/statlab <<'SUDO'
# Statistics Lab: members may restart the reporting daemon themselves.
%statlab ALL=(root) NOPASSWD: /usr/bin/systemctl restart reportd
SUDO
chmod 0440 /etc/sudoers.d/statlab
visudo -cf /etc/sudoers.d/statlab
echo "s3 baseline ready"
