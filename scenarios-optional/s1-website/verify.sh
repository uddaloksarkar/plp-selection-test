#!/usr/bin/env bash
SCENARIO=s1-website
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"

page_ok() { curl -sS --max-time 5 -H 'Host: acmu.isi.local' http://127.0.0.1/ | grep -q 'ACMU-DEPT-PAGE'; }
sub_ok()  { curl -sS --max-time 5 -o /dev/null -w '%{http_code}' -H 'Host: acmu.isi.local' http://127.0.0.1/reports/ | grep -q '^200$'; }
docroot_sane() { local m; m=$(stat -c '%a' /srv/www/acmu); [ "$m" != 777 ] && [ "$m" != 776 ]; }
world_writable() {              # symlinks are always 0777 - only real files/dirs count
  [ -n "$(find /srv/www \( -type f -o -type d \) -perm -0002 -print -quit 2>/dev/null)" ]
}
runs_as_root() { grep -qE '^\s*user\s+root\s*;' /etc/nginx/nginx.conf; }

check 7 s1.page       "site returns the department page on :80" page_ok
check 2 s1.subdir     "/reports/ also serves 200 (docroot perms are recursive)" sub_ok
check 3 s1.conftest   "nginx -t passes"                       nginx -t
check 3 s1.active     "nginx is active"                       systemctl is-active --quiet nginx
check 3 s1.enabled    "nginx is enabled at boot"              systemctl is-enabled --quiet nginx

penalty 4 s1.pen777   "docroot made world-writable"           not docroot_sane
penalty 4 s1.penww    "something under /srv/www is world-writable" world_writable
penalty 5 s1.penroot  "nginx reconfigured to run as root"     runs_as_root
summary
