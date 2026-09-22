# Create the base VM from the cloud image and wait for it to answer ssh.
step "Building the exam VM '$VM_NAME'"
use_build_net

VDI="$PLP_WORK/${VM_NAME}.vdi"
SEED="$PLP_WORK/seed.iso"

if vm_exists "$VM_NAME"; then
  ok "VM already exists"
else
  VBoxManage createvm --name "$VM_NAME" --ostype Ubuntu24_LTS_64 --register >/dev/null
  VBoxManage modifyvm "$VM_NAME" \
      --cpus "$VM_CPUS" --memory "$VM_RAM" --vram 16 \
      --nic1 nat --audio-driver none --graphicscontroller vmsvga \
      --boot1 disk --boot2 none --boot3 none --boot4 none >/dev/null
  VBoxManage storagectl "$VM_NAME" --name SATA --add sata --controller IntelAhci >/dev/null
  VBoxManage storageattach "$VM_NAME" --storagectl SATA --port 0 --device 0 \
      --type hdd --medium "$VDI" >/dev/null
  VBoxManage storagectl "$VM_NAME" --name IDE --add ide >/dev/null
  VBoxManage storageattach "$VM_NAME" --storagectl IDE --port 0 --device 0 \
      --type dvddrive --medium "$SEED" >/dev/null
  ok "created"
fi

# The build needs NAT plus a port forward. A previous run may have left the VM
# on the exam network, and possibly running -- 'modifyvm' refuses to touch a
# running machine, so use 'controlvm' when it is up.
if [ "$(vm_nic1 "$VM_NAME")" != nat ]; then
  say "VM is on the exam network; bringing it back to NAT for the build"
  poweroff_wait "$VM_NAME"
  VBoxManage modifyvm "$VM_NAME" --nic1 nat >/dev/null
fi
if vm_running "$VM_NAME"; then
  VBoxManage controlvm "$VM_NAME" natpf1 delete ssh >/dev/null 2>&1 || true
  VBoxManage controlvm "$VM_NAME" natpf1 "ssh,tcp,127.0.0.1,$SSH_PORT,,22" >/dev/null 2>&1 || true
else
  VBoxManage modifyvm "$VM_NAME" --natpf1 delete ssh >/dev/null 2>&1 || true
  VBoxManage modifyvm "$VM_NAME" --natpf1 "ssh,tcp,127.0.0.1,$SSH_PORT,,22" >/dev/null
fi
ok "ssh forward 127.0.0.1:$SSH_PORT -> :22"

vm_running "$VM_NAME" || { VBoxManage startvm "$VM_NAME" --type headless >/dev/null; ok "started headless"; }

say "First boot runs cloud-init (user, ssh key, disk growth). Takes 1-3 minutes."
wait_for_ssh 420 || die "VM never answered ssh. Look with: VBoxManage startvm $VM_NAME --type gui"
ok "ssh works: ssh -i $PLP_KEY -p $SSH_PORT $ADMIN_USER@127.0.0.1"

# sshd answers well before cloud-init has finished its own package phase, and
# the two would then fight over the apt lock. Wait it out.
say "Waiting for cloud-init to finish (it holds the apt lock)"
vssh "cloud-init status --wait" >/dev/null 2>&1 || true
ok "cloud-init: $(vssh 'cloud-init status' 2>/dev/null | head -1)"
