#!/usr/bin/env bash
# Baseline: an analyst's reporting job running out of a venv, with an offline
# wheelhouse so the scenario works on a VM with no internet during the exam.
# NOTE: provisioning this scenario DOES need internet once, to fill /opt/wheelhouse.
set -euo pipefail
STATE="/var/lib/plp-exam"; install -d -m 0700 "$STATE"
die_s5() { echo "s5 setup: $*" >&2; exit 1; }
P=/srv/projects/analysis

id analyst >/dev/null 2>&1 || useradd -m -s /bin/bash analyst
rm -rf "$P" /opt/legacy /etc/pip.conf /etc/profile.d/zz-legacy-pythonpath.sh
install -d -o analyst -g analyst "$P"

python3 - "$P/data.csv" <<'PY'
import csv, sys
with open(sys.argv[1], "w", newline="") as f:
    w = csv.writer(f); w.writerow(["id", "recorded_on", "value"])
    for i in range(1, 501):
        w.writerow([i, "2026-03-%02d" % (i % 28 + 1), (i * 37) % 101])
PY

cat > "$P/run_report.py" <<'PY'
#!/usr/bin/env python3
"""Nightly summary of the survey extract. Run by cron as the 'analyst' user."""
import csv
import numpy as np
from dateutil import parser as dateparser

rows = []
with open("/srv/projects/analysis/data.csv", newline="") as fh:
    for rec in csv.DictReader(fh):
        dateparser.parse(rec["recorded_on"])
        rows.append(float(rec["value"]))

v = np.array(rows)
print("REPORT-OK rows=%d mean=%.4f sd=%.4f" % (v.size, v.mean(), v.std()))
PY
chown analyst:analyst "$P/run_report.py" "$P/data.csv"
chmod 0644 "$P/data.csv"; chmod 0755 "$P/run_report.py"

printf 'numpy\npython-dateutil\n' > "$P/requirements.in"
runuser -u analyst -- python3 -m venv "$P/.venv"
install -d -m 0755 /opt/wheelhouse

# First provisioning needs PyPI once; every later reset builds from the local
# wheelhouse, so re-arming works on an offline (or egress-firewalled) VM.
if compgen -G "/opt/wheelhouse/*.whl" > /dev/null && [ -f "$STATE/s5-requirements.txt" ]; then
  echo "using existing offline wheelhouse"
  cp "$STATE/s5-requirements.txt" "$P/requirements.txt"
  runuser -u analyst -- "$P/.venv/bin/pip" -q install --no-index \
      --find-links /opt/wheelhouse -r "$P/requirements.txt"
else
  runuser -u analyst -- "$P/.venv/bin/pip" -q install --upgrade pip
  runuser -u analyst -- "$P/.venv/bin/pip" -q install -r "$P/requirements.in"
  runuser -u analyst -- bash -c "'$P/.venv/bin/pip' freeze > '$P/requirements.txt'"
  # the wheelhouse is root-owned, so the download runs as root (it only fetches
  # files, it installs nothing)
  "$P/.venv/bin/pip" -q download -r "$P/requirements.txt" -d /opt/wheelhouse \
    || die_s5 "could not fill /opt/wheelhouse — does this VM have internet?"
  cp "$P/requirements.txt" "$STATE/s5-requirements.txt"
fi
chown -R root:root /opt/wheelhouse
chown analyst:analyst "$P/requirements.txt"
chmod -R a+rX /opt/wheelhouse
cat > /opt/wheelhouse/README.txt <<'TXT'
Approved offline wheel mirror maintained by the systems group.
Install from it with:
    pip install --no-index --find-links /opt/wheelhouse -r requirements.txt
TXT

# record the truth for grading
runuser -l analyst -c "$P/.venv/bin/python $P/run_report.py" > "$STATE/s5-expected.txt"
sha256sum "$P/run_report.py" "$P/data.csv" > "$STATE/s5-files.sha256"
python3 -m pip list --format=freeze 2>/dev/null | sort > "$STATE/s5-syspython.txt"
cat "$STATE/s5-expected.txt"
echo "s5 baseline ready"
