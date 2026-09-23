#!/usr/bin/env bash
# Baseline: a lab machine that cannot be reached publishes its dashboard through
# the campus gateway with a reverse SSH tunnel.
#
#   root ns  = "gateway"  veth-gw  10.20.0.1   sshd :22, user 'tunnel'
#   ns labbox = "labbox"  veth-lab 10.20.0.2   inbound denied by nftables
#     dashboard  python http.server on 127.0.0.1:8888 (inside labbox)
#     lab-tunnel ssh -N -R 0.0.0.0:8080:localhost:8888 tunnel@gateway
#
# Colleagues open http://gateway:8080/ (or http://<exam-ip>:8080/ from the
# candidate's own machine). labbox shares this VM's filesystem, so everything
# that belongs to it lives under /opt/labbox.
set -euo pipefail
STATE="/var/lib/plp-exam"; install -d -m 0700 "$STATE"

systemctl stop lab-tunnel labbox-dashboard labbox-net 2>/dev/null || true

# --- names ------------------------------------------------------------------
sed -i '/[[:space:]]\(gateway\|labbox\)$/d' /etc/hosts
printf '10.20.0.1 gateway\n10.20.0.2 labbox\n' >> /etc/hosts

# --- the lab machine: its own network namespace -----------------------------
install -d -m 0755 /opt/labbox /opt/labbox/dashboard /opt/labbox/ssh
cat > /usr/local/sbin/labbox-net-up <<'NS'
#!/usr/bin/env bash
# Build the labbox namespace. Idempotent.
set -euo pipefail
ip netns del labbox 2>/dev/null || true
ip link del veth-gw 2>/dev/null || true
ip netns add labbox
ip link add veth-gw type veth peer name veth-lab
ip link set veth-lab netns labbox
ip addr add 10.20.0.1/24 dev veth-gw
ip link set veth-gw up
ip -n labbox link set lo up
ip -n labbox addr add 10.20.0.2/24 dev veth-lab
ip -n labbox link set veth-lab up
# Campus IT policy: nothing may connect IN to labbox. Outbound is fine.
ip netns exec labbox nft -f - <<'NFT'
flush ruleset
table inet campus {
  chain input {
    type filter hook input priority 0; policy drop;
    iif lo accept
    ct state established,related accept
  }
}
NFT
NS
chmod 0755 /usr/local/sbin/labbox-net-up

# the candidate's "console" on labbox: a shell inside its namespace
cat > /usr/local/sbin/labbox <<'SH'
#!/bin/sh
# Console on labbox, the basement machine. Nothing can reach it over the
# network, so this is the only way in.   sudo labbox [command...]
[ "$(id -u)" -eq 0 ] || { echo "run it with sudo:  sudo labbox" >&2; exit 1; }
[ -e /run/netns/labbox ] || { echo "labbox is not running (systemctl status labbox-net)" >&2; exit 1; }
[ $# -gt 0 ] && exec ip netns exec labbox "$@"
echo "-- labbox console. 'exit' returns to gateway. --"
exec ip netns exec labbox env PS1='root@labbox:\w# ' bash --norc -i
SH
chmod 0755 /usr/local/sbin/labbox

cat > /etc/systemd/system/labbox-net.service <<'UNIT'
[Unit]
Description=labbox: the basement lab machine (network namespace)
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/labbox-net-up
ExecStop=-/usr/sbin/ip netns del labbox
ExecStop=-/usr/sbin/ip link del veth-gw
[Install]
WantedBy=multi-user.target
UNIT

cat > /opt/labbox/dashboard/index.html <<'HTML'
<!doctype html><title>ACMU Lab - results dashboard</title>
<h1>ACMU Lab results dashboard</h1>
<p>Survey block 1-5: processed. Last run: nightly.</p>
<p>ACMU-DASHBOARD-OK</p>
HTML
cat > /etc/systemd/system/labbox-dashboard.service <<'UNIT'
[Unit]
Description=labbox: results dashboard on 127.0.0.1:8888
Requires=labbox-net.service
After=labbox-net.service
[Service]
NetworkNamespacePath=/run/netns/labbox
ExecStart=/usr/bin/python3 -m http.server 8888 --bind 127.0.0.1 --directory /opt/labbox/dashboard
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
UNIT

# --- the gateway: a key-only account that may do nothing but forward ---------
id tunnel >/dev/null 2>&1 || useradd -m -s /usr/sbin/nologin tunnel
passwd -l tunnel >/dev/null
rm -f /opt/labbox/ssh/id_ed25519 /opt/labbox/ssh/id_ed25519.pub
ssh-keygen -q -t ed25519 -N '' -C 'lab-tunnel@labbox' -f /opt/labbox/ssh/id_ed25519
install -d -m 0700 -o tunnel -g tunnel /home/tunnel/.ssh
printf 'restrict,port-forwarding %s\n' "$(cat /opt/labbox/ssh/id_ed25519.pub)" \
  > /home/tunnel/.ssh/authorized_keys
chown tunnel:tunnel /home/tunnel/.ssh/authorized_keys
chmod 0600 /home/tunnel/.ssh/authorized_keys
chmod 0755 /home/tunnel

# Let the tunnel account's forwards listen on the gateway's network address,
# not just its loopback. Scoped to 'tunnel'; nobody else's settings change.
cat > /etc/ssh/sshd_config.d/60-lab-tunnel.conf <<'SSHD'
# Reverse tunnel from labbox publishes its dashboard on gateway:8080.
Match User tunnel
    AllowTcpForwarding remote
    GatewayPorts clientspecified
    X11Forwarding no
    PermitTTY no
SSHD
chmod 0644 /etc/ssh/sshd_config.d/60-lab-tunnel.conf
sshd -t
systemctl reload ssh 2>/dev/null || systemctl restart ssh

# labbox trusts the gateway's host key (pinned, so the tunnel never prompts)
{ for t in ed25519 ecdsa rsa; do
    f=/etc/ssh/ssh_host_${t}_key.pub
    [ -f "$f" ] && printf 'gateway,10.20.0.1 %s\n' "$(cut -d' ' -f1,2 "$f")"
  done; } > /opt/labbox/ssh/known_hosts
chmod 0644 /opt/labbox/ssh/known_hosts

cat > /etc/systemd/system/lab-tunnel.service <<'UNIT'
[Unit]
Description=labbox: reverse SSH tunnel publishing the dashboard on gateway:8080
Requires=labbox-net.service
After=labbox-net.service labbox-dashboard.service ssh.service
[Service]
NetworkNamespacePath=/run/netns/labbox
# -R [bind_address:]port:host:hostport
#    listen on the GATEWAY at bind_address:port, and send each connection back
#    through the tunnel to host:hostport as seen from labbox
ExecStart=/usr/bin/ssh -N -T \
    -i /opt/labbox/ssh/id_ed25519 \
    -o UserKnownHostsFile=/opt/labbox/ssh/known_hosts \
    -o StrictHostKeyChecking=yes -o BatchMode=yes \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=10 -o ServerAliveCountMax=3 \
    -R 0.0.0.0:8080:localhost:8888 \
    tunnel@gateway
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable labbox-net labbox-dashboard lab-tunnel >/dev/null 2>&1
systemctl restart labbox-net
systemctl restart labbox-dashboard
systemctl restart lab-tunnel

# wait for the published port to answer on the gateway's network address
for _i in $(seq 1 30); do
  curl -fsS -m 2 http://10.20.0.1:8080/ 2>/dev/null | grep -q ACMU-DASHBOARD-OK && break
  sleep 1
done
echo "s7 baseline ready"
