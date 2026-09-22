#!/usr/bin/env bash
# Shared scoring helpers for PLP Part-B verify scripts.
# Contract: every verify.sh prints one line per check and ends with a SCORE line.
#   PASS <pts> <id> <description>
#   FAIL   0   <id> <description>
#   PENALTY -<pts> <id> <description>
#   SCORE <scenario> <earned>/<total>

EXAM_ROOT="${EXAM_ROOT:-/opt/plp-exam}"
STATE_DIR="$EXAM_ROOT/state"
_TOTAL=0
_EARNED=0

check() {            # check <points> <id> <description> <command...>
  local pts=$1 id=$2 desc=$3; shift 3
  _TOTAL=$((_TOTAL + pts))
  if "$@" >/dev/null 2>&1; then
    _EARNED=$((_EARNED + pts))
    printf 'PASS  %3d  %-26s %s\n' "$pts" "$id" "$desc"
  else
    printf 'FAIL    0  %-26s %s\n' "$id" "$desc"
  fi
}

penalty() {          # penalty <points> <id> <description> <command...>  (fires when command succeeds)
  local pts=$1 id=$2 desc=$3; shift 3
  if "$@" >/dev/null 2>&1; then
    _EARNED=$((_EARNED - pts))
    printf 'PENALTY -%d  %-26s %s\n' "$pts" "$id" "$desc"
  fi
}

not() { ! "$@"; }                       # negate a command inside check/penalty
have() { command -v "$1" >/dev/null 2>&1; }

# run a command and compare its stdout (trimmed) to an expected string
out_is() {           # out_is <expected> <command...>
  local want=$1; shift
  local got; got=$("$@" 2>/dev/null | tr -d '\r' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  [ "$got" = "$want" ]
}

out_has() {          # out_has <substring> <command...>
  local want=$1; shift
  "$@" 2>/dev/null | grep -qF -- "$want"
}

summary() {
  printf 'SCORE %s %d/%d\n' "${SCENARIO:-unknown}" "$_EARNED" "$_TOTAL"
}

require_root() {
  [ "$(id -u)" -eq 0 ] || { echo "ERROR: must run as root" >&2; exit 2; }
}

require_exam_vm() {
  [ -f /etc/plp-exam-vm ] || {
    echo "REFUSING TO RUN: /etc/plp-exam-vm marker not found." >&2
    echo "This script is destructive and is only for a disposable exam VM." >&2
    echo "Create the marker with: sudo bash vm/provision.sh --i-know-this-is-a-disposable-vm" >&2
    exit 3
  }
}
