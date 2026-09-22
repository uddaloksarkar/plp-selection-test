#!/usr/bin/env bash
# Baseline: two loop-backed filesystems that model the lab file server.
#   /srv/data   1 GB  ext4   - project data + service logs
#   /srv/spool  48 MB ext4, deliberately inode-poor - job submission spool
set -euo pipefail
STATE="${EXAM_ROOT:-/opt/plp-exam}/state"; install -d "$STATE"
install -d /opt/exam/disks

systemctl stop reportd exam-metrics-collector 2>/dev/null || true
umount /srv/data /srv/spool 2>/dev/null || true
rm -rf /etc/systemd/system/exam-metrics-collector.service.d

for spec in "data:1024:" "spool:48:-N 2048"; do
  name=${spec%%:*}; rest=${spec#*:}; mb=${rest%%:*}; opts=${rest#*:}
  img=/opt/exam/disks/$name.img
  rm -f "$img"
  truncate -s "${mb}M" "$img"
  # shellcheck disable=SC2086
  mkfs.ext4 -q -F $opts "$img"
  # No root reserve. ext4 keeps 5% back for root by default, and the reporting
  # daemon runs as root -- with a reserve it keeps writing long after df says
  # the filesystem is full, and the ticket's first symptom would be false.
  tune2fs -m 0 "$img" >/dev/null
  install -d -m 0755 "/srv/$name"
done

sed -i '\|/opt/exam/disks/|d' /etc/fstab
cat >> /etc/fstab <<'FST'
/opt/exam/disks/data.img   /srv/data   ext4  loop,defaults  0 0
/opt/exam/disks/spool.img  /srv/spool  ext4  loop,defaults  0 0
FST
mount /srv/data
mount /srv/spool

# --- content that must survive -------------------------------------------
install -d -m 0755 /srv/data/current /srv/data/archive /srv/data/logs /srv/data/.cache
for i in 1 2 3 4 5; do
  head -c 200000 /dev/urandom | base64 > "/srv/data/current/survey-block-$i.csv"
done
( cd /srv/data && sha256sum current/* > "$STATE/s2-current.sha256" )

install -d -m 1777 /srv/spool/incoming
install -d -m 0755 /srv/spool/queue
echo "Job spool. Files older than 7 days are purged by cron." > /srv/spool/queue/README

# --- the reporting service: proof that writes work ------------------------
cat > /usr/local/bin/exam-reportd <<'RPT'
#!/bin/bash
while :; do
  echo "$(date -Is) reportd heartbeat" >> /srv/data/logs/reportd.log || true
  sleep 3
done
RPT
chmod 0755 /usr/local/bin/exam-reportd
cat > /etc/systemd/system/reportd.service <<'UNIT'
[Unit]
Description=Departmental reporting daemon
After=srv-data.mount
[Service]
ExecStart=/usr/local/bin/exam-reportd
Restart=always
[Install]
WantedBy=multi-user.target
UNIT

# --- the metrics collector: holds an unlinked spool file open --------------
cat > /usr/local/bin/exam-metrics-collector <<'MET'
#!/usr/bin/env python3
"""Buffers metrics in an unlinked spool file (classic 'deleted but open' bug).

The spool is allocated ONCE PER BOOT: a marker in /run (tmpfs, so it is gone
after a reboot) records that this boot's allocation has been made. That is what
makes restarting the service actually reclaim the space -- which is the whole
lesson of the scenario -- while a reboot still puts the fault back, so the
armed snapshot stays armed.
"""
import os, time

MARKER = "/run/exam-metrics-collector.allocated"
os.makedirs("/srv/data/.cache", exist_ok=True)
path = "/srv/data/.cache/metrics.spool"

leak = os.environ.get("EXAM_LEAK") == "1" and not os.path.exists(MARKER)
fh = open(path, "wb")
if leak:
    open(MARKER, "w").close()
    chunk = b"\0" * (1024 * 1024)
    for _ in range(2048):              # stop early on ENOSPC
        try:
            fh.write(chunk)
        except OSError:
            break
    try:
        fh.flush(); os.fsync(fh.fileno())
    except OSError:
        pass
os.unlink(path)                        # unlinked, still held open
while True:
    time.sleep(5)
MET
chmod 0755 /usr/local/bin/exam-metrics-collector
cat > /etc/systemd/system/exam-metrics-collector.service <<'UNIT'
[Unit]
Description=Lab metrics collector
After=srv-data.mount
[Service]
ExecStart=/usr/local/bin/exam-metrics-collector
Restart=always
RestartSec=3
StartLimitIntervalSec=0
[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now reportd exam-metrics-collector
echo "s2 baseline ready"
