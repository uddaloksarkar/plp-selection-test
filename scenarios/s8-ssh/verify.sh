#!/usr/bin/env bash
SCENARIO=s8-ssh
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"

identity_ok(){ grep -qE '^[[:space:]]*IdentityFile[[:space:]]+\S*id_acmu' /home/candidate/.ssh/config; }
key_perm_ok(){ [ "$(stat -c %a /home/candidate/.ssh/id_acmu)" = 600 ]; }
connects()   { [ "$(runuser -l candidate -c 'ssh -o BatchMode=yes -o ConnectTimeout=8 acmulab whoami' 2>/dev/null)" = acmusrv ]; }

acmusrv_has_password() { passwd -S acmusrv 2>/dev/null | awk '{print $2}' | grep -q '^P$'; }
world_writable()       { [ -n "$(find /home/candidate/.ssh /home/acmusrv/.ssh \( -type f -o -type d \) -perm -0002 -print -quit 2>/dev/null)" ]; }
password_auth_on()     { sshd -T 2>/dev/null | grep -qx 'passwordauthentication yes'; }

check 2 s8.identity "the ssh alias names the key to use"          identity_ok
check 2 s8.keyperm  "the private key is mode 0600"                key_perm_ok
check 6 s8.connect  "ssh acmulab logs in as acmusrv with the key" connects

penalty 3 s8.penpw   "acmusrv given a password to dodge key auth" acmusrv_has_password
penalty 3 s8.pen777  "something under .ssh made world-writable"   world_writable
summary
