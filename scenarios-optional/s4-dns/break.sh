#!/usr/bin/env bash
# Faults: (1) resolv.conf points at a black-holed resolver
#         (2) a stale wrong pin for portal.isi.local in /etc/hosts
#         (3) an invalid address record -> dnsmasq refuses to start
#         (4) nsswitch no longer consults DNS at all
set -euo pipefail
[ -f /etc/plp-exam-vm ] || { echo "not an exam VM" >&2; exit 3; }

sed -i 's/^nameserver .*/nameserver 10.255.255.53/' /etc/resolv.conf
echo "192.0.2.77   portal.isi.local portal" >> /etc/hosts
sed -i 's|^address=/git.isi.local/.*|address=/git.isi.local/10.10.10.999|' /etc/dnsmasq.d/isi-local.conf
sed -i 's/^hosts:.*/hosts:          files/' /etc/nsswitch.conf
systemctl restart dnsmasq 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true
echo "s4 armed"
