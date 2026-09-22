#!/usr/bin/env bash
SCENARIO=s6-vpn
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"

iface_up()  { ip link show wg0 >/dev/null 2>&1; }
handshake() {
  local hs now
  hs=$(wg show wg0 latest-handshakes 2>/dev/null | awk '{print $2}' | sort -rn | head -1)
  now=$(date +%s)
  [ -n "${hs:-}" ] && [ "$hs" -gt 0 ] && [ $(( now - hs )) -lt 180 ]
}
route_ok()  { ip route get 10.100.0.2 2>/dev/null | grep -q 'dev wg0'; }
proxy_ok()  { curl -sS --max-time 6 http://10.100.0.2:8080/ | grep -q 'LIBRARY-PROXY-OK'; }
ufw_on()    { ufw status verbose 2>/dev/null | grep -q 'Status: active'; }
deny_in()   { ufw status verbose 2>/dev/null | grep -q 'deny (incoming)'; }
deny_out()  { ufw status verbose 2>/dev/null | grep -q 'deny (outgoing)'; }
ssh_kept()  { ufw status 2>/dev/null | grep -qE '(^|[[:space:]])22/tcp[[:space:]]+ALLOW'; }
gw_untouched() { [ "$(ip netns exec vpngw wg show wg1 public-key 2>/dev/null)" = "$(cat "$STATE_DIR/s6-gw.pub")" ]; }

check 1 s6.iface     "wg0 exists"                              iface_up
check 4 s6.handshake "tunnel has a recent handshake"           handshake
check 2 s6.route     "10.100.0.0/24 routes over wg0"           route_ok
check 5 s6.proxy     "e-library proxy answers over the tunnel" proxy_ok
check 1 s6.ufwon     "ufw still active"                        ufw_on
check 1 s6.denyin    "default-deny incoming preserved"         deny_in
check 3 s6.denyout   "default-deny EGRESS preserved (policy)"  deny_out
check 1 s6.ssh       "ssh rule still present"                  ssh_kept

penalty 6 s6.penoff  "firewall switched off instead of opened" not ufw_on
penalty 5 s6.pengw   "the gateway end was reconfigured (wrong side fixed)" not gw_untouched
summary
