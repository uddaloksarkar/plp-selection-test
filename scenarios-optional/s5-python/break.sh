#!/usr/bin/env bash
# Faults: (1) venv points at an interpreter that no longer exists
#         (2) a global PYTHONPATH shadows numpy with a stale stub
#         (3) a rogue csv.py in the project directory shadows the stdlib
#         (4) /etc/pip.conf points at an unreachable internal index
set -euo pipefail
[ -f /etc/plp-exam-vm ] || { echo "not an exam VM" >&2; exit 3; }
P=/srv/projects/analysis

# (1) "the 3.9 packages were cleaned up during the upgrade"
sed -i 's|^home = .*|home = /opt/python-3.9/bin|' "$P/.venv/pyvenv.cfg"
sed -i 's|^version.*|version = 3.9.18|' "$P/.venv/pyvenv.cfg" 2>/dev/null || true
ln -sfn /usr/bin/python3.9 "$P/.venv/bin/python"
ln -sfn /usr/bin/python3.9 "$P/.venv/bin/python3"

# (2) a leftover from the old shared library tree
install -d /opt/legacy/pylibs/numpy
cat > /opt/legacy/pylibs/numpy/__init__.py <<'PY'
# frozen snapshot of numpy 1.16 shipped with the 2019 cluster image
__version__ = "1.16.0-legacy"
raise ImportError("legacy numpy stub: rebuilt package not available on this host")
PY
cat > /etc/profile.d/zz-legacy-pythonpath.sh <<'SH'
# added 2019 for the old cluster tools
export PYTHONPATH=/opt/legacy/pylibs
SH

# (3) someone's scratch file, sitting next to the script
cat > "$P/csv.py" <<'PY'
# quick test of the csv export, ignore  -- a.
def writer(*a, **k):
    raise NotImplementedError("scratch file, do not import")
PY
chown analyst:analyst "$P/csv.py"

# (4) pip points at an index that no longer exists
cat > /etc/pip.conf <<'CONF'
[global]
index-url = https://pypi.internal.isi.local/simple
trusted-host = pypi.internal.isi.local
timeout = 15
CONF
echo "s5 armed"
