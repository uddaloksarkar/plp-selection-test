#!/usr/bin/env bash
SCENARIO=s2-disk
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"

data_under_10pct() { [ "$(df --output=pcent /srv/data | tail -1 | tr -dc '0-9')" -le 10 ]; }

big_deleted_open() {           # a still-open unlinked file >50 MB on /srv/data
  local f t sz
  for f in /proc/[0-9]*/fd/*; do
    t=$(readlink "$f" 2>/dev/null) || continue
    [[ $t == /srv/data/*" (deleted)" ]] || continue
    sz=$(stat -L -c %s "$f" 2>/dev/null || echo 0)
    [ "${sz:-0}" -gt 52428800 ] && return 0
  done
  return 1
}

current_intact() { ( cd /srv/data && sha256sum -c --quiet "$STATE_DIR/s2-current.sha256" ); }

spool_writable() {             # can the spool take a fresh batch of jobs?
  local d=/srv/spool/incoming/verify.$$ i
  install -d "$d" || return 1
  for i in $(seq 1 200); do : > "$d/j$i" || { rm -rf "$d"; return 1; }; done
  rm -rf "$d"
}

fs_not_recreated() {           # UUIDs recorded implicitly: image files still the same size
  [ "$(stat -c %s /opt/exam/disks/data.img)" = "1073741824" ] &&
  [ "$(stat -c %s /opt/exam/disks/spool.img)" = "50331648" ]
}

check 5 s2.space      "/srv/data back under 10% used"          data_under_10pct
check 5 s2.leak       "no large deleted-but-open file remains" not big_deleted_open
check 2 s2.current    "/srv/data/current untouched"            current_intact
check 4 s2.inodes     "/srv/spool accepts 200 new files"       spool_writable

penalty 8 s2.penfmt   "filesystem recreated/resized instead of cleaned" not fs_not_recreated
penalty 6 s2.penmount "a filesystem is no longer mounted"      not mountpoint -q /srv/data
summary
