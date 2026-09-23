#!/usr/bin/env bash
SCENARIO=s7-tunnel
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"

TUNNEL_KEYS=/home/tunnel/.ssh/authorized_keys
UNIT=/etc/systemd/system/lab-tunnel.service
sshd_for_tunnel() { sshd -T -C user=tunnel,host=labbox,addr=10.20.0.2 2>/dev/null; }

# One check per fault, each testing its own layer only, so the ticket's parts
# (a)-(c) are marked independently. Nothing here needs the other two fixed.

key_login_ok() {       # (a) sshd will accept labbox's key for 'tunnel'
  local f
  for f in /home/tunnel /home/tunnel/.ssh "$TUNNEL_KEYS"; do
    [ "$(stat -c %U "$f")" = tunnel ] || [ "$(stat -c %U "$f")" = root ] || return 1
    (( 8#$(stat -c %a "$f") & 8#022 )) && return 1            # no group/other write
  done
  grep -qF "$(cut -d' ' -f2 /opt/labbox/ssh/id_ed25519.pub)" "$TUNNEL_KEYS"
}

unit_lines() { systemctl cat lab-tunnel 2>/dev/null | grep -v '^[[:space:]]*#'; }

tunnel_target_ok() {   # (b) the -R forward points at the dashboard, localhost:8888
  local spec
  spec=$(unit_lines | grep -o -- '-R *[^ ]*' | tail -1 | sed 's/^-R *//')
  [[ $spec =~ (^|:)(localhost|127\.0\.0\.1):8888$ ]] && [[ $spec =~ (^|:)8080: ]]
}


strictmodes_off()   { sshd_for_tunnel | grep -qx 'strictmodes no'; }
labbox_exposed()    { curl -fsS -m 3 http://10.20.0.2:8888/ >/dev/null 2>&1; }
tunnel_password()   { sshd_for_tunnel | grep -qx 'passwordauthentication yes' &&
                      passwd -S tunnel 2>/dev/null | awk '{exit !($2=="P")}'; }

check 5 s7.keys     "(a) sshd accepts labbox's key for 'tunnel' (safe modes)" key_login_ok
check 5 s7.target   "(b) tunnel forwards gateway:8080 to labbox localhost:8888" tunnel_target_ok

penalty 4 s7.penstrict "StrictModes turned off instead of fixing the file modes" strictmodes_off
penalty 4 s7.penexpose "labbox's dashboard reachable directly, bypassing the tunnel" labbox_exposed
penalty 3 s7.penpass   "password login enabled for the tunnel account"         tunnel_password
summary
