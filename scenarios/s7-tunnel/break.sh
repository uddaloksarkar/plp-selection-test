#!/usr/bin/env bash
# Faults — two independent layers of one reverse tunnel:
#   (1) gateway: tunnel's authorized_keys made world-writable -> sshd's
#       StrictModes refuses the key ("Permission denied (publickey)")
#   (2) labbox:  the tunnel forwards to localhost:8889; the dashboard is on 8888
set -euo pipefail
[ -f /etc/plp-exam-vm ] || { echo "not an exam VM" >&2; exit 3; }

# (1)
chmod 0666 /home/tunnel/.ssh/authorized_keys   # 0664 is not enough: Ubuntu lets
                                                # group-write pass for a private group

# (2)
sed -i 's|-R 0\.0\.0\.0:8080:localhost:8888|-R 0.0.0.0:8080:localhost:8889|' \
  /etc/systemd/system/lab-tunnel.service


systemctl daemon-reload
systemctl restart lab-tunnel
sleep 3

# --- assert the faults actually took ------------------------------------------
fail() { echo "s7 break FAILED: $*" >&2; exit 1; }
[ "$(stat -c %a /home/tunnel/.ssh/authorized_keys)" = 666 ] || fail "authorized_keys mode"
grep -q -- '-R 0.0.0.0:8080:localhost:8889' /etc/systemd/system/lab-tunnel.service || fail "tunnel target"
curl -fsS -m 3 http://10.20.0.1:8080/ >/dev/null 2>&1 && fail "dashboard still reachable on gateway:8080"
echo "s7 armed"
