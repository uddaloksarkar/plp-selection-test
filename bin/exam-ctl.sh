#!/usr/bin/env bash
# PLP Part-B control plane. Run on the exam VM as root.
#   exam-ctl.sh setup   [scenario...]   build the healthy baseline
#   exam-ctl.sh health  [scenario...]   verify the baseline (must be 100%)
#   exam-ctl.sh arm     [scenario...]   inject the faults
#   exam-ctl.sh score   [scenario...]   grade the candidate's work
#   exam-ctl.sh reset   [scenario...]   rebuild baseline, then re-arm
#   exam-ctl.sh list
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export EXAM_ROOT="${EXAM_ROOT:-$HERE}"
source "$HERE/lib/checks.sh"

ALL=(s2-disk s3-permissions s4-dns)
cmd="${1:-list}"; shift || true
sel=("$@"); [ ${#sel[@]} -eq 0 ] && sel=("${ALL[@]}")

run_stage() { # run_stage <scenario> <script> — fails loudly, and stops the run
  local s=$1 f="$HERE/scenarios/$1/$2"
  [ -x "$f" ] || { echo "-- $s/$2 missing, skipped"; return 0; }
  echo "== $s :: $2"
  if ! EXAM_ROOT="$EXAM_ROOT" bash "$f"; then
    echo >&2
    echo "!!! $s/$2 FAILED — stopping. Nothing after this ran." >&2
    echo "    Fix it, then re-run:  bash bin/exam-ctl.sh ${cmd} $s" >&2
    exit 1
  fi
}

case "$cmd" in
  list)  printf '%s\n' "${ALL[@]}" ;;
  setup) require_root; require_exam_vm; for s in "${sel[@]}"; do run_stage "$s" setup.sh; done ;;
  arm)   require_root; require_exam_vm; for s in "${sel[@]}"; do run_stage "$s" break.sh; done
         echo; echo "Faults armed. Snapshot the VM now as 'armed'." ;;
  reset) require_root; require_exam_vm
         for s in "${sel[@]}"; do run_stage "$s" setup.sh; run_stage "$s" break.sh; done ;;
  health) require_root; "$HERE/vm/healthcheck.sh" "${sel[@]}" ;;
  score)  require_root; "$HERE/bin/score.sh" "${sel[@]}" ;;
  *) echo "unknown command: $cmd" >&2; exit 1 ;;
esac
