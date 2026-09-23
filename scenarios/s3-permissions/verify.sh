#!/usr/bin/env bash
SCENARIO=s3-permissions
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"
SHARED=/srv/projects/acmu/shared

dir_mode_ok() {                 # setgid set, group rw, not world-writable
  local m g o
  m=$(stat -c %a /srv/projects/acmu)          # "2775"; a non-setgid dir gives 3 digits
  [ "${#m}" -eq 4 ] || return 1
  case "${m:0:1}" in 2|3|6|7) ;; *) return 1 ;; esac   # the setgid bit, however set
  g=${m:2:1}; o=${m:3:1}
  (( (g & 6) == 6 )) || return 1                 # group can read and write
  (( (o & 2) == 0 )) || return 1                 # others cannot write
}
dir_group_ok() { [ "$(stat -c %G /srv/projects/acmu)" = acmu ]; }
buddhadev_member() { id -nG buddhadev | tr ' ' '\n' | grep -qx acmu; }

# Each check tests one fault. Part (b) is tested as arnab, who stays a member,
# so it does not also depend on buddhadev being re-added in part (a).
member_creates_group_file() {   # tests group write AND the setgid inheritance
  local f="$SHARED/.verify.$$" g rc=1
  runuser -u arnab -- bash -c ": > '$f'" 2>/dev/null || return 1
  g=$(stat -c %G "$f" 2>/dev/null); [ "$g" = acmu ] && rc=0
  rm -f "$f"; return $rc
}
notes_shared() {                # group acmu, group rw (with an ACL, %a shows the mask)
  local m; m=$(stat -c %a "$SHARED/notes.md")
  [ "$(stat -c %G "$SHARED/notes.md")" = acmu ] && (( (${m: -2:1} & 6) == 6 ))
}
arnab_sudo_ok()      { runuser -u arnab -- sudo -n /usr/bin/systemctl restart reportd; }
chandrima_reads()      { runuser -u chandrima -- cat "$SHARED/notes.md"; }
chandrima_writes()     { local f="$SHARED/.aud.$$"; runuser -u chandrima -- bash -c ": > '$f'" 2>/dev/null && { rm -f "$f"; return 0; }; return 1; }
chandrima_in_group()   { id -nG chandrima | tr ' ' '\n' | grep -qx acmu; }
world_writable()     {          # symlinks are always 0777 - only real files/dirs count
  [ -n "$(find /srv/projects \( -type f -o -type d \) -perm -0002 -print -quit 2>/dev/null)" ]
}
sudoers_valid()      { visudo -cf /etc/sudoers.d/acmu; }

check 3 s3.dirmode   "shared dir is setgid + group-writable"   dir_mode_ok
check 1 s3.dirgroup  "shared dir group is acmu"             dir_group_ok
check 2 s3.member    "buddhadev is back in the acmu group"     buddhadev_member
check 4 s3.groupwrite "a member creates files that land in group acmu" member_creates_group_file
check 2 s3.notes     "notes.md is group acmu, group read-write" notes_shared
check 2 s3.sudo      "arnab can 'sudo -n systemctl restart reportd'" arnab_sudo_ok
check 1 s3.sudosyn   "sudoers drop-in still parses"            sudoers_valid
check 1 s3.aclread   "auditor chandrima can read notes.md"       chandrima_reads

penalty 4 s3.penacl  "auditor can WRITE (over-granted)"        chandrima_writes
penalty 4 s3.pengrp  "auditor was added to acmu instead of ACL" chandrima_in_group
penalty 5 s3.pen777  "something under /srv/projects is world-writable" world_writable
summary
