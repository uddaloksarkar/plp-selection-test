#!/usr/bin/env bash
# Baseline: departmental nginx vhost statlab.isi.local serving /srv/www/statlab
set -euo pipefail
install -d -m 0755 /srv/www/statlab
cat > /srv/www/statlab/index.html <<'HTML'
<!doctype html><html><head><title>Statistics Lab — ISI</title></head>
<body><h1>Statistics Laboratory</h1>
<p id="token">STATLAB-DEPT-PAGE</p>
<p>Seminar schedule, datasets and technical reports.</p></body></html>
HTML
install -d -m 0755 /srv/www/statlab/reports
echo "annual report placeholder" > /srv/www/statlab/reports/index.html
chown -R www-data:www-data /srv/www/statlab
chmod -R u=rwX,g=rX,o=rX /srv/www/statlab

cat > /etc/nginx/sites-available/statlab <<'CONF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name statlab.isi.local www.isi.local _;
    root /srv/www/statlab;
    index index.html;
    access_log /var/log/nginx/statlab.access.log;
    error_log  /var/log/nginx/statlab.error.log;
    location / { try_files $uri $uri/ =404; }
}
CONF
rm -f /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/zz-legacy.conf
ln -sfn /etc/nginx/sites-available/statlab /etc/nginx/sites-enabled/statlab
nginx -t
systemctl enable --now nginx
systemctl restart nginx
echo "s1 baseline ready"
