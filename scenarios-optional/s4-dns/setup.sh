#!/usr/bin/env bash
# Baseline: dnsmasq acts as the "campus resolver" for the isi.local zone.
# systemd-resolved's stub is taken out of the path so /etc/resolv.conf is a real file.
set -euo pipefail
UP=$(awk '/^nameserver/ && $2 !~ /^127\./ {print $2; exit}' \
      /run/systemd/resolve/resolv.conf /etc/resolv.conf 2>/dev/null || true)
[ -n "${UP:-}" ] || UP=8.8.8.8

systemctl disable --now systemd-resolved >/dev/null 2>&1 || true

# On a desktop/NetworkManager install, NM rewrites /etc/resolv.conf on every
# network event and would silently undo this scenario. Take it out of the path.
if systemctl list-unit-files 2>/dev/null | grep -q '^NetworkManager\.service'; then
  install -d -m 0755 /etc/NetworkManager/conf.d
  printf '[main]\ndns=none\nrc-manager=unmanaged\n' \
    > /etc/NetworkManager/conf.d/90-exam-dns.conf
  systemctl reload-or-restart NetworkManager 2>/dev/null || true
fi

# no-hosts: serve only the zone records. By default dnsmasq also serves /etc/hosts, read
# once at start -- so fixing the resolver before removing the stale portal pin
# left dnsmasq handing out the pin over DNS until it was restarted, coupling two
# otherwise independent faults and letting hosts-file entries pass as DNS.
cat > /etc/dnsmasq.d/isi-local.conf <<CONF
# Campus resolver for the isi.local zone
listen-address=127.0.0.1
bind-interfaces
no-resolv
server=$UP
domain-needed
bogus-priv
no-hosts
log-queries

address=/www.isi.local/127.0.0.1
address=/acmu.isi.local/127.0.0.1
address=/portal.isi.local/127.0.0.1
address=/git.isi.local/10.10.10.9
address=/nas.isi.local/10.10.10.20
CONF

chattr -i /etc/resolv.conf 2>/dev/null || true
rm -f /etc/resolv.conf
cat > /etc/resolv.conf <<'RC'
# Campus resolver. Managed by the system group - do not point this elsewhere.
nameserver 127.0.0.1
search isi.local
options timeout:1 attempts:2
RC

# a clean, ordinary hosts file and nsswitch line
sed -i '/isi\.local/d' /etc/hosts
grep -qE '^127\.0\.1\.1' /etc/hosts || echo "127.0.1.1 $(hostname)" >> /etc/hosts
sed -i 's/^hosts:.*/hosts:          files dns/' /etc/nsswitch.conf

systemctl enable --now dnsmasq
systemctl restart dnsmasq
sleep 1
echo "s4 baseline ready"
