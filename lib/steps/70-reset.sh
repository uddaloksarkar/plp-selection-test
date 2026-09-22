# Rebuild one scenario on this machine's VM, mid-exam.
SCEN="${1:-}"
[ -n "$SCEN" ] || die "usage: ./plp reset <scenario>
  scenarios: $(ls "$PLP_ROOT/scenarios" | tr '\n' ' ')"
[ -d "$PLP_ROOT/scenarios/$SCEN" ] || die "no such scenario: $SCEN"

step "Rebuilding and re-arming $SCEN"
detect_net || die "cannot reach the VM"
vrsync /tmp/plp-exam/ >/dev/null || die "copy failed"
vssh "sudo rm -rf /opt/plp-exam && sudo cp -a /tmp/plp-exam /opt/plp-exam &&
      sudo bash /opt/plp-exam/scenarios/$SCEN/reset.sh &&
      sudo rm -rf /opt/plp-exam /tmp/plp-exam" || die "reset failed"
ok "$SCEN rebuilt — note the lost time on the candidate's sheet"
