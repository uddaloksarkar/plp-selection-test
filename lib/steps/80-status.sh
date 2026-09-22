step "$VM_NAME"
vm_exists "$VM_NAME" || { echo "  not built yet — run ./plp up"; return 0 2>/dev/null || exit 0; }
printf '  %-14s %s\n' state "$(vm_state "$VM_NAME")"
printf '  %-14s %s\n' network "$(vm_nic1 "$VM_NAME")"
printf '  %-14s %s\n' snapshots "$(VBoxManage snapshot "$VM_NAME" list --machinereadable 2>/dev/null \
    | sed -n 's/^SnapshotName[^=]*="\(.*\)"/\1/p' | tr '\n' ' ')"
if detect_net 2>/dev/null; then
  printf '  %-14s %s\n' reachable "$VM_SSH_HOST:$VM_SSH_PORT"
  printf '  %-14s %s\n' harness "$(vssh 'test -e /opt/plp-exam && echo PRESENT- do not hand out || echo removed' 2>/dev/null)"
  printf '  %-14s %s\n' tickets "$(vssh 'sudo ls /home/candidate/tickets 2>/dev/null | wc -l' 2>/dev/null) files"
else
  printf '  %-14s %s\n' reachable "no"
fi
echo
echo "  Candidate logs in with:  ssh candidate@$EXAM_IP     (password: $CAND_PASSWORD)"
