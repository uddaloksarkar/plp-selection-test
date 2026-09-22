#!/usr/bin/env bash
# Baseline: a WireGuard tunnel from this host to a "remote campus gateway".
# The remote end is a network namespace on this same VM, so the whole scenario
# works with no internet and no second machine.
#
#   root ns  wg0 10.100.0.1  <== tunnel ==>  ns 'vpngw'  wg1 10.100.0.2
#   underlay veth 10.10.0.1  <---------->    veth 10.10.0.2:51820/udp
#   inside the ns: http://10.100.0.2:8080  = the "e-library proxy"
set -euo pipefail
STATE="/var/lib/plp-exam"; install -d -m 0700 "$STATE"
umask 077
install -d -m 0700 /etc/wireguard

[ -f /etc/wireguard/server.key ] || { wg genkey > /etc/wireguard/server.key; }
[ -f /etc/wireguard/gw.key ]     || { wg genkey > /etc/wireguard/gw.key; }
wg pubkey < /etc/wireguard/server.key > /etc/wireguard/server.pub
wg pubkey < /etc/wireguard/gw.key     > /etc/wireguard/gw.pub
chmod 0600 /etc/wireguard/*.key; chmod 0644 /etc/wireguard/*.pub

umask 022
install -d -m 0755 /srv/vpn-content
cat > /srv/vpn-content/index.html <<'HTML'
<!doctype html><title>Campus e-library proxy</title>
<h1>Campus e-library proxy</h1><p>LIBRARY-PROXY-OK</p>
HTML

cat > /usr/local/sbin/exam-vpngw-up.sh <<'NS'
#!/usr/bin/env bash
# Build the simulated remote gateway namespace. Idempotent.
set -euo pipefail
ip netns del vpngw 2>/dev/null || true
ip link del veth-vpn 2>/dev/null || true
ip netns add vpngw
ip link add veth-vpn type veth peer name veth-gw
ip link set veth-gw netns vpngw
ip addr add 10.10.0.1/24 dev veth-vpn
ip link set veth-vpn up
ip -n vpngw link set lo up
ip -n vpngw addr add 10.10.0.2/24 dev veth-gw
ip -n vpngw link set veth-gw up
# The interface MUST be created inside the namespace. A wireguard interface
# keeps its UDP socket in the namespace it was CREATED in, so the usual
# "create in root, move with ip link set netns" pattern would leave the
# gateway listening on 51820 in the ROOT namespace and no handshake happens.
ip netns exec vpngw ip link add wg1 type wireguard
ip netns exec vpngw wg set wg1 \
    listen-port 51820 \
    private-key /etc/wireguard/gw.key \
    peer "$(cat /etc/wireguard/server.pub)" \
    allowed-ips 10.100.0.1/32
ip -n vpngw addr add 10.100.0.2/24 dev wg1
ip -n vpngw link set wg1 up
NS
chmod 0755 /usr/local/sbin/exam-vpngw-up.sh

cat > /etc/systemd/system/exam-vpngw.service <<'UNIT'
[Unit]
Description=Simulated remote campus VPN gateway (netns)
After=network-online.target
[Service]
Type=simple
ExecStartPre=/usr/local/sbin/exam-vpngw-up.sh
ExecStart=/bin/sh -c 'exec ip netns exec vpngw python3 -m http.server 8080 --bind 10.100.0.2 --directory /srv/vpn-content'
ExecStopPost=-/usr/sbin/ip netns del vpngw
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
UNIT

cat > /etc/wireguard/wg0.conf <<CONF
# Campus VPN - client end. Issued by Central IT.
[Interface]
Address = 10.100.0.1/24
PrivateKey = $(cat /etc/wireguard/server.key)

[Peer]
# campus gateway
PublicKey = $(cat /etc/wireguard/gw.pub)
AllowedIPs = 10.100.0.0/24
Endpoint = 10.10.0.2:51820
PersistentKeepalive = 15
CONF
chmod 0600 /etc/wireguard/wg0.conf

install -d -m 0755 /etc/systemd/system/wg-quick@wg0.service.d
printf '[Unit]\nAfter=exam-vpngw.service\nRequires=exam-vpngw.service\n' \
  > /etc/systemd/system/wg-quick@wg0.service.d/order.conf

# the handover note the candidate is meant to find
install -d -m 0755 /opt/vpn-handover
cat > /opt/vpn-handover/central-it-email.txt <<MAIL
From:    Central IT, Network Services
To:      Statistics Lab systems contact
Subject: Campus VPN parameters for your host  [KEEP THIS]

Your client interface  : 10.100.0.1/24  (wg0)
Gateway endpoint       : 10.10.0.2:51820   (UDP)
Gateway public key     : $(cat /etc/wireguard/gw.pub)
Networks reachable
  through the tunnel   : 10.100.0.0/24
Service behind it      : http://10.100.0.2:8080/   (e-library proxy)

Reminder: campus security policy requires hosts to run with a default-deny
egress firewall. Open the specific flows you need; do not turn the firewall off.
MAIL
chmod 0644 /opt/vpn-handover/central-it-email.txt
cp /etc/wireguard/gw.pub "$STATE/s6-gw.pub"

systemctl daemon-reload
# 'enable --now' does nothing to an already-active unit, which would leave a
# stale namespace from a previous run in place. Restart explicitly.
systemctl enable exam-vpngw.service >/dev/null
systemctl restart exam-vpngw.service
sleep 3

ufw --force reset >/dev/null
ufw default deny incoming  >/dev/null
ufw default deny outgoing  >/dev/null
ufw allow 22/tcp           >/dev/null
ufw allow 80/tcp           >/dev/null
ufw allow out 53           >/dev/null
ufw allow out to 10.10.0.2 port 51820 proto udp >/dev/null
ufw allow out to 10.100.0.0/24 >/dev/null
ufw --force enable >/dev/null

systemctl enable wg-quick@wg0 >/dev/null
systemctl restart wg-quick@wg0
sleep 4
wg show wg0 || true
echo "s6 baseline ready"
