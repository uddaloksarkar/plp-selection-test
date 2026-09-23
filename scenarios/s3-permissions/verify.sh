#!/usr/bin/env bash
SCENARIO=s3-permissions
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"
SHARED=/srv/projects/acmu/shared

dir_mode_ok() {                 # group can read and write, others cannot write
  local m g o
  m=$(stat -c %a /srv/projects/acmu)
  m=${m: -3}                                   # ignore any setuid/setgid/sticky digit
  g=${m:1:1}; o=${m:2:1}
  (( (g & 6) == 6 )) || return 1               # group read + write
  (( (o & 2) == 0 )) || return 1               # others cannot write
}
dir_group_ok() { [ "$(stat -c %G /srv/projects/acmu)" = acmu ]; }
buddhadev_member() { id -nG buddhadev | tr ' ' '\n' | grep -qx acmu; }

# Each check tests one fault. Part (b) is tested as arnab, who stays a member,
# so it does not also depend on buddhadev being re-added in part (a).
member_can_write() {            # a group member can create a file in the shared area
  local f="$SHARED/.verify.$$"
  runuser -u buddhadev -- bash -c ": > '$f'" 2>/dev/null || return 1
  rm -f "$f"
}
  local m; m=$(stat -c %a "$SHARED/notes.md")
  [ "$(stat -c %G "$SHARED/notes.md")" = acmu ] && (( (${m: -2:1} & 6) == 6 ))
}
chandrima_reads()      { runuser -u chandrima -- cat "$SHARED/notes.md"; }
chandrima_writes()     { local f="$SHARED/.aud.$$"; runuser -u chandrima -- bash -c ": > '$f'" 2>/dev/null && { rm -f "$f"; return 0; }; return 1; }
chandrima_in_group()   { id -nG chandrima | tr ' ' '\n' | grep -qx acmu; }
world_writable()     {          # symlinks are always 0777 - only real files/dirs count
  [ -n "$(find /srv/projects \( -type f -o -type d \) -perm -0002 -print -quit 2>/dev/null)" ]
}

check 3 s3.dirmode   "shared dir is group-writable, not world-writable" dir_mode_ok
check 1 s3.dirgroup  "shared dir group is acmu"             dir_group_ok
check 5 s3.member    "buddhadev is back in the acmu group"     buddhadev_member
check 4 s3.groupwrite "a group member can create files in shared/" member_can_write
check 3 s3.aclread   "auditor chandrima can read notes.md"       chandrima_reads

penalty 4 s3.penacl  "auditor can WRITE (over-granted)"        chandrima_writes
penalty 4 s3.pengrp  "auditor was added to acmu instead of ACL" chandrima_in_group
penalty 5 s3.pen777  "something under /srv/projects is world-writable" world_writable
summary
