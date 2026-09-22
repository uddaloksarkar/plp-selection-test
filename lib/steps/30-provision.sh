# Push the harness onto the VM, build the six baselines, snapshot 'golden'.
step "Provisioning the exam environment"
use_build_net

vm_running "$VM_NAME" || { VBoxManage startvm "$VM_NAME" --type headless >/dev/null; wait_for_ssh 300 || die "no ssh"; }
vssh true 2>/dev/null || wait_for_ssh 300 || die "no ssh to $VM_NAME"

say "Copying the harness"
vrsync_harness || die "copy failed"
ok "harness at /opt/plp-exam"

say "Running provision.sh (packages, three baselines, wheelhouse, health check)"
vssh "sudo bash /opt/plp-exam/vm/provision.sh --i-know-this-is-a-disposable-vm --unminimize" \
  || die "provisioning failed — read the output above; the last FAIL line names the scenario"

say "Pinning the exam address ($EXAM_IP) inside the VM"
# A placeholder keeps the heredoc fully quoted, so nothing here is expanded
# by the local shell, by ssh, or by sh on the far side.
vssh 'sudo tee /usr/local/sbin/plp-examnet >/dev/null' <<'SCRIPT'
#!/bin/sh
# Give the exam VM a fixed address on the host-only network, whatever the
# interface is called. Harmless while the VM is still on NAT.
IF=$(ls /sys/class/net | grep -E '^(en|eth)' | head -n1)
[ -n "$IF" ] || exit 0
ip link set "$IF" up
ip addr replace __EXAM_IP__/24 dev "$IF"
SCRIPT
vssh "sudo sed -i 's|__EXAM_IP__|$EXAM_IP|' /usr/local/sbin/plp-examnet && sudo chmod 0755 /usr/local/sbin/plp-examnet"

vssh 'sudo tee /etc/systemd/system/plp-examnet.service >/dev/null' <<'UNIT'
[Unit]
Description=Fixed host-only address for the exam VM
After=network.target
[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/plp-examnet
[Install]
WantedBy=multi-user.target
UNIT
vssh "sudo systemctl daemon-reload && sudo systemctl enable --now plp-examnet.service" \
  || die "could not pin the exam address"
vssh "ip -4 addr show | grep -q '$EXAM_IP'" \
  || die "the VM did not take $EXAM_IP — check /usr/local/sbin/plp-examnet on the VM"
ok "VM answers on $EXAM_IP once it is on the host-only network"

# Fingerprint the setup scripts. arm compares against this: the baseline it
# arms is a SNAPSHOT, and anything setup.sh installs on the machine (helper
# programs in /usr/local/bin, mkfs options) is frozen in it. Editing a setup.sh
# and re-running only `arm` would silently arm the old baseline.
vssh "sudo sh -c 'cat /opt/plp-exam/scenarios/*/setup.sh | sha256sum | cut -d\" \" -f1 > /var/lib/plp-exam/setup.sha256'"
ok "baseline fingerprint recorded"

say "Setting the candidate password for this sitting"
vssh "echo 'candidate:$CAND_PASSWORD' | sudo chpasswd"
ok "candidate / $CAND_PASSWORD"

# the seed ISO has done its job
VBoxManage storageattach "$VM_NAME" --storagectl IDE --port 0 --device 0 \
    --type dvddrive --medium none >/dev/null 2>&1 || true

say "Snapshotting 'golden'"
poweroff_wait "$VM_NAME"
snap_exists "$VM_NAME" golden && VBoxManage snapshot "$VM_NAME" delete golden >/dev/null 2>&1 || true
VBoxManage snapshot "$VM_NAME" take golden --description "healthy baseline, harness present" >/dev/null
ok "snapshot: golden"
