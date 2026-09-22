#!/usr/bin/env bash
# Faults: (1) duplicate default_server -> nginx config invalid
#         (2) docroot ownership/permission -> 403 once nginx starts
#         (3) unit stopped and disabled
set -euo pipefail
[ -f /etc/plp-exam-vm ] || { echo "not an exam VM" >&2; exit 3; }

# (1) a "legacy" vhost someone copied in last week
cat > /etc/nginx/sites-enabled/zz-legacy.conf <<'CONF'
# added by intern during the migration - do not delete without asking (2025-11-04)
server {
    listen 80 default_server;
    server_name old-statlab.isi.local;
    root /srv/www/legacy;
    index index.html;
}
CONF
install -d -m 0755 /srv/www/legacy
echo "legacy site" > /srv/www/legacy/index.html

# (2) someone "secured" the docroot
chown -R root:root /srv/www/statlab
chmod 0700 /srv/www/statlab

# (3) service left down and disabled after the failed restart
systemctl stop nginx 2>/dev/null || true
systemctl disable nginx 2>/dev/null || true
echo "s1 armed"
