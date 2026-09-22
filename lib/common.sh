#!/usr/bin/env bash
# Shared helpers for the plp tool. Sourced by every step.
set -euo pipefail

PLP_ROOT="${PLP_ROOT:?}"
PLP_WORK="$PLP_ROOT/.plp"
PLP_KEY="$PLP_WORK/id_ed25519"

# defaults, then plp.conf overrides
VM_NAME=plp-exam
UBUNTU_RELEASE=24.04
DISK_MB=25600
VM_RAM=4096
VM_CPUS=2
EXAM_IP=192.168.56.10
HOSTONLY_HOST_IP=192.168.56.1
SSH_PORT=2222
CAND_PASSWORD=plp2026
ADMIN_USER=examadmin
[ -f "$PLP_ROOT/plp.conf" ] && . "$PLP_ROOT/plp.conf"

if [ -t 1 ]; then B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; Rd=$'\e[31m'; N=$'\e[0m'
else B=; G=; Y=; Rd=; N=; fi
say()  { printf '%s==>%s %s\n' "$B" "$N" "$*"; }
ok()   { printf '  %s✓%s %s\n' "$G" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$Y" "$N" "$*" >&2; }
die()  { printf '%sERROR:%s %s\n' "$Rd" "$N" "$*" >&2; exit 1; }
step() { printf '\n%s── %s %s\n' "$B" "$*" "$N"; }

have()      { command -v "$1" >/dev/null 2>&1; }
vm_exists() { VBoxManage showvminfo "$1" >/dev/null 2>&1; }
vm_state()  { VBoxManage showvminfo "$1" --machinereadable 2>/dev/null | sed -n 's/^VMState="\(.*\)"/\1/p'; }
vm_running(){ [ "$(vm_state "$1")" = running ]; }
vm_nic1()   { VBoxManage showvminfo "$1" --machinereadable 2>/dev/null | sed -n 's/^nic1="\(.*\)"/\1/p'; }
snap_exists(){ VBoxManage snapshot "$1" list --machinereadable 2>/dev/null | grep -q "SnapshotName.*=\"$2\""; }

# --- ssh: two possible paths to the same VM ----------------------------------
#   build  : NAT + port forward   127.0.0.1:$SSH_PORT
#   exam   : host-only, fixed     $EXAM_IP:22        (no internet)
SSHOPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
         -o LogLevel=ERROR -o ConnectTimeout=5)
VM_SSH_HOST=127.0.0.1
VM_SSH_PORT="$SSH_PORT"
use_build_net() { VM_SSH_HOST=127.0.0.1;  VM_SSH_PORT="$SSH_PORT"; }
use_exam_net()  { VM_SSH_HOST="$EXAM_IP"; VM_SSH_PORT=22; }

vssh() { ssh "${SSHOPTS[@]}" -i "$PLP_KEY" -p "$VM_SSH_PORT" "$ADMIN_USER@$VM_SSH_HOST" "$@"; }
vscp_from() { scp "${SSHOPTS[@]}" -i "$PLP_KEY" -P "$VM_SSH_PORT" "$ADMIN_USER@$VM_SSH_HOST:$1" "$2"; }
vrsync() { rsync -a --delete -e "ssh ${SSHOPTS[*]} -i $PLP_KEY -p $VM_SSH_PORT" \
             --exclude '.plp/' --exclude 'build/' --exclude 'marks/' --exclude 'plp.conf' \
             "$PLP_ROOT/" "$ADMIN_USER@$VM_SSH_HOST:$1"; }

# Refresh /opt/plp-exam in place, PRESERVING its state/ directory. That holds
# truth generated on the VM at setup time -- the sha256 manifest of the live
# data, the expected report output -- and the verify scripts compare against it.
# rsync's --delete does not remove excluded paths, so state/ survives.
vrsync_harness() {
  rsync -a --delete --rsync-path="sudo rsync" \
        -e "ssh ${SSHOPTS[*]} -i $PLP_KEY -p $VM_SSH_PORT" \
        --exclude 'state/' --exclude '.plp/' --exclude 'build/' \
        --exclude 'marks/' --exclude 'plp.conf' --exclude '.git/' \
        "$PLP_ROOT/" "$ADMIN_USER@$VM_SSH_HOST:/opt/plp-exam/"
}

# pick whichever network the VM is currently answering on
detect_net() {
  use_exam_net;  vssh true 2>/dev/null && return 0
  use_build_net; vssh true 2>/dev/null && return 0
  return 1
}

wait_for_ssh() {   # wait_for_ssh <seconds>
  local deadline=$(( $(date +%s) + ${1:-300} ))
  printf '  waiting for ssh on %s:%s ' "$VM_SSH_HOST" "$VM_SSH_PORT"
  while [ "$(date +%s)" -lt "$deadline" ]; do
    if vssh true 2>/dev/null; then echo " up"; return 0; fi
    printf '.'; sleep 5
  done
  echo; return 1
}

poweroff_wait() {
  local vm=$1 i
  vm_running "$vm" || return 0
  VBoxManage controlvm "$vm" acpipowerbutton >/dev/null 2>&1 || true
  for i in $(seq 1 30); do vm_running "$vm" || return 0; sleep 2; done
  warn "graceful shutdown timed out, forcing"
  VBoxManage controlvm "$vm" poweroff >/dev/null 2>&1 || true
  sleep 3
}

# the host-only interface the exam VM lives on; created once, no root needed
ensure_hostonly() {
  local ifn out
  ifn=$(VBoxManage list hostonlyifs 2>/dev/null | awk '/^Name:/{print $2; exit}')
  if [ -z "$ifn" ]; then
    out=$(VBoxManage hostonlyif create 2>&1) || true
    ifn=$(printf '%s' "$out" | sed -n "s/.*Interface '\([^']*\)' was successfully created.*/\1/p")
    [ -n "$ifn" ] || ifn=$(VBoxManage list hostonlyifs 2>/dev/null | awk '/^Name:/{print $2; exit}')
  fi
  [ -n "$ifn" ] || return 1
  VBoxManage hostonlyif ipconfig "$ifn" --ip "$HOSTONLY_HOST_IP" --netmask 255.255.255.0 >/dev/null 2>&1 || true
  echo "$ifn"
}
