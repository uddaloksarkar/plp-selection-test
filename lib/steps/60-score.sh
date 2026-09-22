# Grade this machine's exam VM.
step "Scoring $VM_NAME"
detect_net || die "cannot reach the VM — is it running? ./plp status"
ok "reached at $VM_SSH_HOST:$VM_SSH_PORT"

mkdir -p "$PLP_ROOT/marks"
STAMP=$(date +%Y%m%d-%H%M)
OUT="$PLP_ROOT/marks/$STAMP"

say "Pushing the harness back"
vrsync /tmp/plp-exam/ || die "copy failed"
vssh "sudo rm -rf /opt/plp-exam && sudo mv /tmp/plp-exam /opt/plp-exam"

say "Running every verify.sh"
vssh "sudo bash /opt/plp-exam/bin/score.sh" | tee "$OUT.txt"
# scp cannot read inside 0750 /home/candidate as examadmin; go through sudo
vssh "sudo cat /home/candidate/FIXLOG.md" > "$OUT-fixlog.md" 2>/dev/null \
  || warn "no FIXLOG.md on the VM"
vssh "sudo cat /var/log/exam-audit.log" > "$OUT-audit.log" 2>/dev/null || warn "no audit log"

step "Marks written"
printf '  %s\n' "$OUT.txt" "$OUT-fixlog.md" "$OUT-audit.log"
echo
echo "  Add the FIXLOG and viva marks by hand — docs/scoring-sheet.md"
