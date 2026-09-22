#!/usr/bin/env bash
# Faults: (1) wrong peer public key      -> handshake never completes
#         (2) AllowedIPs on the wrong net -> no route into 10.100.0.0/24
#         (3) egress firewall drops the tunnel's UDP and the tunnel subnet
#         (4) wg-quick@wg0 stopped and disabled
set -euo pipefail
[ -f /etc/plp-exam-vm ] || { echo "not an exam VM" >&2; exit 3; }
systemctl stop wg-quick@wg0 2>/dev/null || true

DECOY=$(wg genkey | wg pubkey)
sed -i "s|^PublicKey = .*|PublicKey = $DECOY|" /etc/wireguard/wg0.conf
sed -i "s|^AllowedIPs = .*|AllowedIPs = 192.168.250.0/24|" /etc/wireguard/wg0.conf

ufw --force reset >/dev/null
ufw default deny incoming >/dev/null
ufw default deny outgoing >/dev/null
ufw allow 22/tcp          >/dev/null
ufw allow 80/tcp          >/dev/null
ufw allow out 53          >/dev/null
ufw --force enable >/dev/null

systemctl disable wg-quick@wg0 2>/dev/null || true
echo "s6 armed"
