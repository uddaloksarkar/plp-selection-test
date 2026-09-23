#!/usr/bin/env bash
SCENARIO=s4-dns
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"

resolves_to() {   # resolves_to <expected-ip> <name>   (and must answer inside 2s)
  local want=$1 name=$2 ip
  ip=$(timeout 2 getent hosts "$name" 2>/dev/null | awk 'NR==1{print $1}')
  [ "$ip" = "$want" ]
}
dig_direct() {    # answered by the resolver itself, not by /etc/hosts
  [ "$(dig +short +time=1 +tries=1 @127.0.0.1 git.isi.local 2>/dev/null | head -1)" = "10.10.10.9" ]
}
hosts_clean()    { ! grep -qE '(^|[[:space:]])[a-z0-9.-]*isi\.local' /etc/hosts; }
nsswitch_dns()   { grep -qE '^hosts:.*\bdns\b' /etc/nsswitch.conf; }
resolv_local()   { [ "$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf 2>/dev/null)" = 127.0.0.1 ]; }
resolv_immutable() { lsattr /etc/resolv.conf 2>/dev/null | grep -q 'i'; }

# One check per layer, so the ticket's parts (a)-(d) are marked independently:
# each uses a test that bypasses the other layers. Only (e) needs all four.
check 3 s4.nsswitch "(a) nsswitch consults dns for hosts"        nsswitch_dns
check 3 s4.resolv   "(b) resolv.conf sends queries to 127.0.0.1" resolv_local
check 2 s4.dnsmasq  "(c) dnsmasq is active and enabled"          bash -c 'systemctl is-active --quiet dnsmasq && systemctl is-enabled --quiet dnsmasq'
check 2 s4.viadns   "(c) the resolver itself answers git.isi.local -> 10.10.10.9" dig_direct
check 2 s4.hosts    "(d) /etc/hosts has no isi.local entries at all" hosts_clean
check 2 s4.www      "(e) www.isi.local -> 127.0.0.1 (fast)"      resolves_to 127.0.0.1 www.isi.local
check 1 s4.portal   "(e) portal.isi.local -> 127.0.0.1, not the stale pin" resolves_to 127.0.0.1 portal.isi.local
check 1 s4.git      "(e) git.isi.local -> 10.10.10.9"            resolves_to 10.10.10.9 git.isi.local

penalty 3 s4.penimm "/etc/resolv.conf made immutable with chattr" resolv_immutable
summary
