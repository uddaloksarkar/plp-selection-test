#!/usr/bin/env bash
# Baseline: a shared group project area + a delegated sudo rule + a read-only auditor
set -euo pipefail
getent group acmu >/dev/null || groupadd acmu
for u in arnab buddhadev chandrima; do
  id "$u" >/dev/null 2>&1 || useradd -m -s /bin/bash "$u"
done
gpasswd -M arnab,buddhadev acmu >/dev/null      # chandrima is deliberately NOT a member

install -d -m 0755 /srv/projects
install -d /srv/projects/acmu/shared
chown -R root:acmu /srv/projects/acmu
# Members only: no access for "other". The auditor reads through his ACL alone,
# so wiping it is a fault of its own -- with an o+r baseline he could read
# everything anyway, and fixing notes.md would silently fix the auditor too.
chmod 2770 /srv/projects/acmu
chmod 2770 /srv/projects/acmu/shared

cat > /srv/projects/acmu/shared/notes.md <<'MD'
# Sampling notes — shared working file
Everyone in the acmu group edits this; the internal auditor reads it.
MD
chown root:acmu /srv/projects/acmu/shared/notes.md
chmod 0660 /srv/projects/acmu/shared/notes.md

# read-only auditor access, without putting him in the group
setfacl -R  -m u:chandrima:rX /srv/projects/acmu
setfacl -d -m u:chandrima:rX /srv/projects/acmu
setfacl -d -m u:chandrima:rX /srv/projects/acmu/shared

# delegated restart right for the group
cat > /etc/sudoers.d/acmu <<'SUDO'
# ACMU Lab: members may restart the reporting daemon themselves.
%acmu ALL=(root) NOPASSWD: /usr/bin/systemctl restart reportd
SUDO
chmod 0440 /etc/sudoers.d/acmu
visudo -cf /etc/sudoers.d/acmu
echo "s3 baseline ready"
