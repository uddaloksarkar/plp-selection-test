#!/usr/bin/env bash
SCENARIO=s5-python
source "${EXAM_ROOT:-/opt/plp-exam}/lib/checks.sh"
P=/srv/projects/analysis
VPY="$P/.venv/bin/python"

report_ok() {   # exact match against the output recorded from the healthy baseline
  local want got
  want=$(cat "$STATE_DIR/s5-expected.txt")
  got=$(runuser -l analyst -c "$VPY $P/run_report.py" 2>/dev/null)
  [ -n "$want" ] && [ "$got" = "$want" ]
}
venv_healthy() {
  [ "$(runuser -l analyst -c "$VPY -c 'import sys;print(sys.prefix)'" 2>/dev/null)" = "$P/.venv" ]
}
numpy_from_venv() {
  runuser -l analyst -c "$VPY -c 'import numpy;print(numpy.__file__)'" 2>/dev/null \
    | grep -q "^$P/.venv/"
}
no_shadowing() { ! ls "$P"/csv.py "$P"/numpy.py "$P"/json.py "$P"/random.py >/dev/null 2>&1; }
pythonpath_clear() {
  [ "$(runuser -l analyst -c 'echo "${PYTHONPATH:-unset}"' 2>/dev/null)" = unset ]
}
system_python_untouched() {
  diff -q <(python3 -m pip list --format=freeze 2>/dev/null | sort) "$STATE_DIR/s5-syspython.txt"
}
venv_owned_by_analyst() { [ "$(stat -c %U "$P/.venv/bin/python")" = analyst ]; }
sources_untouched() { sha256sum -c --quiet "$STATE_DIR/s5-files.sha256"; }

check 6 s5.report    "run_report.py produces the expected output as analyst" report_ok
check 2 s5.venv      "the venv resolves to a working interpreter"  venv_healthy
check 2 s5.numpysrc  "numpy is imported from the venv, not /opt/legacy" numpy_from_venv
check 2 s5.shadow    "no module-shadowing file left in the project dir" no_shadowing
check 2 s5.pypath    "no global PYTHONPATH in a login shell"       pythonpath_clear
check 2 s5.syspy     "system python's packages are untouched"      system_python_untouched

penalty 4 s5.penown  "venv not owned by analyst (built as root)"   not venv_owned_by_analyst
penalty 8 s5.pensrc  "run_report.py or data.csv was modified"      not sources_untouched
summary
