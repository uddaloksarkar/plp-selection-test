#!/usr/bin/env bash
SCENARIO=s3-permissions
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"
SHARED=/srv/projects/statlab/shared

dir_mode_ok() {                 # setgid set, group rw, not world-writable
  local m g o
  m=$(stat -c %a /srv/projects/statlab)          # "2775"; a non-setgid dir gives 3 digits
  [ "${#m}" -eq 4 ] || return 1
  case "${m:0:1}" in 2|3|6|7) ;; *) return 1 ;; esac   # the setgid bit, however set
  g=${m:2:1}; o=${m:3:1}
  (( (g & 6) == 6 )) || return 1                 # group can read and write
  (( (o & 2) == 0 )) || return 1                 # others cannot write
}
dir_group_ok() { [ "$(stat -c %G /srv/projects/statlab)" = statlab ]; }
bikram_member() { id -nG bikram | tr ' ' '\n' | grep -qx statlab; }

bikram_creates_group_file() {   # tests group write AND the setgid inheritance
  local f="$SHARED/.verify.$$" g rc=1
  runuser -u bikram -- bash -c ": > '$f'" 2>/dev/null || return 1
  g=$(stat -c %G "$f" 2>/dev/null); [ "$g" = statlab ] && rc=0
  rm -f "$f"; return $rc
}
bikram_reads_notes() { runuser -u bikram -- cat "$SHARED/notes.md"; }
anita_sudo_ok()      { runuser -u anita -- sudo -n /usr/bin/systemctl restart reportd; }
chandan_reads()      { runuser -u chandan -- cat "$SHARED/notes.md"; }
chandan_writes()     { local f="$SHARED/.aud.$$"; runuser -u chandan -- bash -c ": > '$f'" 2>/dev/null && { rm -f "$f"; return 0; }; return 1; }
chandan_in_group()   { id -nG chandan | tr ' ' '\n' | grep -qx statlab; }
world_writable()     {          # symlinks are always 0777 - only real files/dirs count
  [ -n "$(find /srv/projects \( -type f -o -type d \) -perm -0002 -print -quit 2>/dev/null)" ]
}
sudoers_valid()      { visudo -cf /etc/sudoers.d/statlab; }

check 3 s3.dirmode   "shared dir is setgid + group-writable"   dir_mode_ok
check 1 s3.dirgroup  "shared dir group is statlab"             dir_group_ok
check 3 s3.member    "bikram is back in the statlab group"     bikram_member
check 4 s3.groupwrite "bikram creates files that land in group statlab" bikram_creates_group_file
check 2 s3.notes     "bikram can read shared/notes.md"         bikram_reads_notes
check 3 s3.sudo      "anita can 'sudo -n systemctl restart reportd'" anita_sudo_ok
check 1 s3.sudosyn   "sudoers drop-in still parses"            sudoers_valid
check 1 s3.aclread   "auditor chandan can read notes.md"       chandan_reads

penalty 4 s3.penacl  "auditor can WRITE (over-granted)"        chandan_writes
penalty 4 s3.pengrp  "auditor was added to statlab instead of ACL" chandan_in_group
penalty 5 s3.pen777  "something under /srv/projects is world-writable" world_writable
summary
