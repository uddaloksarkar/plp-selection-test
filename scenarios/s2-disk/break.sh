#!/usr/bin/env bash
# Faults: (1) the metrics collector leaks a 300 MB unlinked file  (df != du)
#         (2) old archive dumps fill the rest of /srv/data
#         (3) /srv/spool runs out of inodes, not bytes
#
# The sizing matters and is not arbitrary. The leak is a deleted-but-open file,
# so it dies with its process at every shutdown and must be re-created at every
# boot -- including the boot that follows `arm` and every `rearm`. For that to
# work the archive dumps must leave EXACTLY enough free space for the collector
# to take its 300 MB back. Fill the disk completely here and the collector
# cannot re-leak, the df/du gap disappears, and the ticket loses its point.
set -euo pipefail
[ -f /etc/plp-exam-vm ] || { echo "not an exam VM" >&2; exit 3; }

LEAK_MB=300


# (1) arm the leak, but do not start it yet
install -d /etc/systemd/system/exam-metrics-collector.service.d
printf '[Service]\nEnvironment=EXAM_LEAK=1\n' \
  > /etc/systemd/system/exam-metrics-collector.service.d/leak.conf
systemctl daemon-reload
systemctl stop exam-metrics-collector 2>/dev/null || true
sleep 2                                   # let any held blocks come back

# (2) dumps that are "already backed up", sized to leave room for the leak
install -d /srv/data/archive
cat > /srv/data/archive/README.txt <<'TXT'
Monthly dumps. Everything here up to 2025-09 has been verified on the tape
library and on the off-site copy; these files are safe to remove locally.
TXT

avail=$(df --output=avail -k /srv/data | tail -1)
fill=$(( avail - LEAK_MB * 1024 - 512 ))   # 512 KB of slack
if [ "$fill" -gt 0 ]; then
  per=$(( fill / 4 ))
  for m in 06 07 08 09; do
    fallocate -l "${per}K" "/srv/data/archive/dump-2025-${m}.tar.gz" 2>/dev/null || \
      dd if=/dev/zero of="/srv/data/archive/dump-2025-${m}.tar.gz" bs=1K count="$per" status=none
  done
fi

# now let the collector take the remaining space and hold it open
systemctl start exam-metrics-collector
# wait for the collector to finish claiming its spool
for _i in $(seq 1 60); do
  _g=$(( $(df -k /srv/data | awk 'NR==2{print $3}') - $(du -sk /srv/data 2>/dev/null | cut -f1) ))
  [ "$_g" -gt $(( (LEAK_MB - 50) * 1024 )) ] && break
  sleep 1
done
sync

# (3) a runaway cron left thousands of tiny files -> inode exhaustion
install -d /srv/spool/stale
i=0
while [ $i -lt 4000 ]; do
  { : > "/srv/spool/stale/job-$i.lock"; } 2>/dev/null || break
  i=$((i+1))
done

systemctl start reportd 2>/dev/null || true

# --- assert the faults actually took -----------------------------------------
# A break script that half-worked produces an exam whose marks are wrong, and
# the failure is invisible until scoring. Fail loudly here instead.
gap=$(( $(df -k /srv/data | awk 'NR==2{print $3}') - $(du -sk /srv/data 2>/dev/null | cut -f1) ))
[ "$gap" -gt $(( (LEAK_MB - 50) * 1024 )) ] \
  || { echo "s2 break FAILED: df/du gap is only ${gap} KB - the leak did not establish" >&2; exit 1; }
[ "$(df --output=pcent -k /srv/data | tail -1 | tr -dc 0-9)" -ge 99 ] \
  || { echo "s2 break FAILED: /srv/data is not full" >&2; exit 1; }
touch /srv/spool/incoming/_probe 2>/dev/null \
  && { rm -f /srv/spool/incoming/_probe; echo "s2 break FAILED: /srv/spool still accepts files" >&2; exit 1; }

echo "s2 armed (df/du gap ${gap} KB, spool stale files: $i)"
