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
#!/usr/bin/env python3
"""Departmental reporting daemon.

Writes with O_DSYNC on purpose. With ext4's delayed allocation an ordinary
append to a full filesystem SUCCEEDS into the page cache, updates the file's
mtime, and only fails later at writeback -- so the log would look like it was
still being written when in fact nothing could be persisted. A synchronous
write allocates immediately and returns ENOSPC, so the log genuinely stops.
The daemon keeps running and keeps trying, which is what the users see.
"""
import os, time, datetime

LOG = "/srv/data/logs/reportd.log"
os.makedirs(os.path.dirname(LOG), exist_ok=True)
while True:
    line = datetime.datetime.now().isoformat() + " reportd heartbeat\n"
    try:
        fd = os.open(LOG, os.O_WRONLY | os.O_APPEND | os.O_CREAT | os.O_DSYNC, 0o644)
        try:
            os.write(fd, line.encode())
        finally:
            os.close(fd)
    except OSError:
        pass          # no space: keep running, keep failing, exactly as reported
    time.sleep(3)
RPT
chmod 0755 /usr/local/bin/exam-reportd
cat > /etc/systemd/system/reportd.service <<'UNIT'
[Unit]
Description=Departmental reporting daemon
After=srv-data.mount exam-metrics-collector.service
[Service]
# Let the metrics collector claim its spool first. Without this, reportd gets
# a write in during the seconds before the filesystem fills, which allocates a
# fresh block and keeps it writing for several minutes -- so "the log stopped
# updating" would not be true just after a rearm.
ExecStartPre=/bin/sleep 25
ExecStart=/usr/local/bin/exam-reportd
Restart=always
[Install]
WantedBy=multi-user.target
UNIT

# --- the metrics collector: holds an unlinked spool file open --------------
cat > /usr/local/bin/exam-metrics-collector <<'MET'
#!/usr/bin/env python3
"""Buffers metrics in an unlinked spool file (classic 'deleted but open' bug).

Two details matter.

  * The spool is allocated ONCE PER BOOT, recorded by a marker in /run (tmpfs,
    so a reboot clears it). That is what lets restarting the service actually
    reclaim the space -- the lesson of the scenario -- while a reboot still
    puts the fault back, keeping the armed snapshot armed.

  * Writes are synchronous (O_DSYNC) and step down to 4K at the end. With
    ext4's delayed allocation a buffered write to a full filesystem succeeds
    and only fails later at writeback, so the spool would stop short and leave
    free space behind -- enough for the reporting daemon to keep writing.
"""
import os, time

MARKER = "/run/exam-metrics-collector.allocated"
os.makedirs("/srv/data/.cache", exist_ok=True)
path = "/srv/data/.cache/metrics.spool"

leak = os.environ.get("EXAM_LEAK") == "1" and not os.path.exists(MARKER)
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_DSYNC, 0o600)
if leak:
    open(MARKER, "w").close()
    for size, limit in ((1024 * 1024, 2048), (4096, 512)):
        blob = b"\0" * size
        for _ in range(limit):
            try:
                os.write(fd, blob)
            except OSError:
                break                      # full at this granularity; try finer
os.unlink(path)                            # unlinked, still held open
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
