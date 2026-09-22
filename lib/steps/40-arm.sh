# Inject the faults, install the candidate bundle, delete the harness,
# snapshot 'armed', then put the VM on the offline host-only network.
step "Arming the faults"
use_build_net

vm_running "$VM_NAME" || VBoxManage startvm "$VM_NAME" --type headless >/dev/null
wait_for_ssh 300 || die "no ssh to $VM_NAME"

# Never arm a baseline that has not been verified. Arming a dirty box produces
# an exam whose marks mean nothing, and the failure is invisible until scoring.
say "Syncing the harness to the VM"
vrsync_harness || die "copy failed"
ok "harness up to date (state/ preserved)"

say "Checking the baseline matches these setup scripts"
want=$(cat "$PLP_ROOT"/scenarios/*/setup.sh | sha256sum | cut -d' ' -f1)
have=$(vssh "sudo cat /opt/plp-exam/state/setup.sha256 2>/dev/null" || echo none)
if [ "$want" != "$have" ]; then
  die "the 'golden' snapshot was built from different setup scripts.
    Anything setup.sh installs on the machine is baked into that snapshot, so
    arming it would use the OLD baseline. Run:  ./plp provision"
fi
ok "baseline matches"

say "Re-checking the baseline before arming"
vssh "sudo test -x /opt/plp-exam/vm/healthcheck.sh" 2>/dev/null \
  || die "no harness on the VM — run ./plp provision first"
vssh "sudo bash /opt/plp-exam/vm/healthcheck.sh" >/dev/null 2>&1 \
  || die "baseline is NOT clean — refusing to arm. Run ./plp provision and read its output."
ok "baseline clean"

vssh "sudo bash /opt/plp-exam/bin/exam-ctl.sh arm" || die "arming failed"
ok "all scenarios armed"

say "Installing the candidate bundle and removing the harness"
vssh "echo yes | sudo bash /opt/plp-exam/bin/seal.sh" || die "seal failed"
vssh "test -e /opt/plp-exam" 2>/dev/null && die "harness still on the VM — refusing to snapshot"
# /home/candidate is mode 0750 on Ubuntu, so even looking needs root
n=$(vssh "sudo ls /home/candidate/tickets 2>/dev/null | wc -l")
[ "${n:-0}" -ge 4 ] || die "candidate tickets missing (found ${n:-0}, expected 4)"
vssh "sudo test -s /home/candidate/FIXLOG.md" || die "candidate FIXLOG.md missing"
ok "VM carries tickets only; answers are gone"

# The network must be switched BEFORE the snapshot: a VirtualBox snapshot
# captures the VM's settings as well as its disk, so a snapshot taken while the
# VM is still on NAT would restore to NAT and never appear on $EXAM_IP.
step "Taking the VM offline for the exam"
HOIF=$(ensure_hostonly) || die "could not create a host-only interface"
poweroff_wait "$VM_NAME"
VBoxManage modifyvm "$VM_NAME" --nic1 hostonly --host-only-adapter1 "$HOIF" >/dev/null
VBoxManage modifyvm "$VM_NAME" --natpf1 delete ssh >/dev/null 2>&1 || true
ok "nic1 -> $HOIF (no internet)"

say "Snapshotting 'armed'"
snap_exists "$VM_NAME" armed && VBoxManage snapshot "$VM_NAME" delete armed >/dev/null 2>&1 || true
VBoxManage snapshot "$VM_NAME" take armed --description "faults injected, harness removed, offline" >/dev/null
ok "snapshot: armed"

VBoxManage startvm "$VM_NAME" --type headless >/dev/null
use_exam_net
wait_for_ssh 240 || die "VM did not come up on $EXAM_IP — check with: VBoxManage startvm $VM_NAME --type gui"
vssh "ping -c1 -W2 1.1.1.1" >/dev/null 2>&1 \
  && warn "the VM still has internet — expected none" \
  || ok "confirmed offline"
