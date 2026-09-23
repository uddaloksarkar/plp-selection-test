#!/usr/bin/env bash
# Baseline: departmental nginx vhost acmu.isi.local serving /srv/www/acmu
set -euo pipefail
install -d -m 0755 /srv/www/acmu
cat > /srv/www/acmu/index.html <<'HTML'
<!doctype html><html><head><title>ACMU Lab — ISI</title></head>
<body><h1>ACMU Laboratory</h1>
<p id="token">ACMU-DEPT-PAGE</p>
<p>Seminar schedule, datasets and technical reports.</p></body></html>
HTML
install -d -m 0755 /srv/www/acmu/reports
echo "annual report placeholder" > /srv/www/acmu/reports/index.html
chown -R www-data:www-data /srv/www/acmu
chmod -R u=rwX,g=rX,o=rX /srv/www/acmu

cat > /etc/nginx/sites-available/acmu <<'CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name acmu.isi.local www.isi.local _;
    root /srv/www/acmu;
    index index.html;
    access_log /var/log/nginx/acmu.access.log;
    error_log  /var/log/nginx/acmu.error.log;
    location / { try_files $uri $uri/ =404; }
}
CONF
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/zz-legacy.conf
ln -sfn /etc/nginx/sites-available/acmu /etc/nginx/sites-enabled/acmu
nginx -t
systemctl enable --now nginx
systemctl restart nginx
echo "s1 baseline ready"
