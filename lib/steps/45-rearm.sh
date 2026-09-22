# Put the VM back to its pristine armed state, for the next candidate.
step "Restoring '$VM_NAME' to the armed snapshot"
vm_exists "$VM_NAME" || die "no VM yet — run ./plp up"
snap_exists "$VM_NAME" armed || die "no 'armed' snapshot — run ./plp arm"

warn "This discards everything the previous candidate did. Their work should already be scored."
read -r -p "  Type 'rearm' to confirm: " a
[ "$a" = rearm ] || die "cancelled"

poweroff_wait "$VM_NAME"
VBoxManage snapshot "$VM_NAME" restore armed >/dev/null || die "restore failed"
# A snapshot restores settings too. Force the exam network in case the snapshot
# was taken by an older build that captured the VM while it was still on NAT.
HOIF=$(ensure_hostonly) || die "could not create a host-only interface"
VBoxManage modifyvm "$VM_NAME" --nic1 hostonly --host-only-adapter1 "$HOIF" >/dev/null
VBoxManage modifyvm "$VM_NAME" --natpf1 delete ssh >/dev/null 2>&1 || true
ok "restored, nic1 -> $HOIF"

VBoxManage startvm "$VM_NAME" --type headless >/dev/null
use_exam_net
wait_for_ssh 240 || die "VM did not come up on $EXAM_IP"
ok "ready for the next candidate at $EXAM_IP (candidate / $CAND_PASSWORD)"
