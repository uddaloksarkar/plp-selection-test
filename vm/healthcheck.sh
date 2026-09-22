#!/usr/bin/env bash
# Invariant: on a pristine, unbroken baseline every check must PASS (100%).
# If it does not, the fault is in setup.sh, not in the candidate.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out=$(bash "$HERE/bin/score.sh" "$@")
echo "$out"
if echo "$out" | grep -qE '^(FAIL|PENALTY)'; then
  echo; echo "BASELINE NOT CLEAN — the lines above should all be PASS." >&2
  exit 1
fi
echo; echo "Baseline clean."
