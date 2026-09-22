step "Destroying $VM_NAME"
vm_exists "$VM_NAME" || { echo "  nothing to destroy"; return 0 2>/dev/null || exit 0; }
echo "  This deletes the VM and its snapshots. Downloaded images in .plp/ are kept."
read -r -p "  Type 'destroy' to confirm: " a
[ "$a" = destroy ] || die "cancelled"
VBoxManage controlvm "$VM_NAME" poweroff >/dev/null 2>&1 || true
sleep 2
VBoxManage unregistervm "$VM_NAME" --delete >/dev/null
ok "removed. Rebuild any time with ./plp up"
