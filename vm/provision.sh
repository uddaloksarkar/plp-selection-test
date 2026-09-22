#!/usr/bin/env bash
# One-time build of the PLP Part-B exam VM.
# Target: Ubuntu Server 24.04 LTS (22.04 also works), 25 GB disk.
#   Build the golden VM with 4 GB RAM; candidate clones run fine on 2 GB / 2 vCPU.
# MUST be run on a disposable VM with internet access (the wheelhouse needs PyPI once).
#   sudo bash vm/provision.sh --i-know-this-is-a-disposable-vm
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 2; }

if [ "${1:-}" = "--i-know-this-is-a-disposable-vm" ]; then
  echo "PLP exam VM. Everything here is disposable. Provisioned $(date -Is)" > /etc/plp-exam-vm
fi
[ -f /etc/plp-exam-vm ] || { echo "Refusing: /etc/plp-exam-vm marker missing (see usage above)." >&2; exit 3; }

echo "### 1/5 packages"
export DEBIAN_FRONTEND=noninteractive
# cloud-init or unattended-upgrades may still hold the apt lock on a fresh boot
for _i in $(seq 1 60); do
  pgrep -f 'apt-get|unattended-upgrade' >/dev/null 2>&1 || break
  [ "$_i" = 1 ] && echo "  waiting for another apt process to finish..."
  sleep 5
done
apt-get update -qq
apt-get install -y -qq \
  nginx dnsmasq wireguard wireguard-tools ufw \
  python3 python3-venv python3-pip \
  acl attr lsof psmisc tree jq curl dnsutils net-tools iproute2 iputils-ping \
  tcpdump nftables iptables man-db bash-completion vim nano less rsync

# On VirtualBox, guest utils let the host read the VM's address
# (bin/clone-candidates.sh --ips depends on it).
if grep -qi virtualbox /sys/class/dmi/id/product_name 2>/dev/null; then
  apt-get install -y -qq virtualbox-guest-utils || true
fi

# A "minimized" Ubuntu image excludes man pages and docs. The exam VM is
# offline, so man is the candidate's only reference — refuse to ship without it.
if ls /etc/dpkg/dpkg.cfg.d/*excludes* >/dev/null 2>&1 || ! man ls >/dev/null 2>&1; then
  if [ "${PLP_UNMINIMIZE:-}" = 1 ] || [ "${2:-}" = "--unminimize" ]; then
    echo "--- minimized image detected: restoring documentation (this takes a few minutes)"
    rm -f /etc/dpkg/dpkg.cfg.d/*excludes*
    if command -v unminimize >/dev/null 2>&1; then
      yes | unminimize || true
    else
      # No unminimize on this image: restore the base man pages and reinstall
      # only the packages whose manuals the exam actually leans on.
      apt-get install -y -qq --reinstall man-db manpages manpages-dev || true
      apt-get install -y -qq --reinstall coreutils util-linux procps \
        systemd nginx dnsmasq wireguard-tools ufw acl lsof iproute2 \
        findutils grep sed tar python3 || true
    fi
    man ls >/dev/null 2>&1 || echo "WARNING: man still unavailable after repair" >&2
  else
    cat >&2 <<'WARN'

!!! This looks like a MINIMIZED Ubuntu image: `man` is missing or documentation
    is excluded by /etc/dpkg/dpkg.cfg.d/excludes.

    The exam VM is offline, so man pages are the candidate's only reference and
    the candidate instructions promise they are present.

    Fix it and re-run provisioning:
        sudo bash vm/provision.sh --i-know-this-is-a-disposable-vm --unminimize
    or rebuild the VM from the standard (non-minimized) Ubuntu Server image.

WARN
    exit 4
  fi
fi

# cloud-init regenerates /etc/hosts on every boot when manage_etc_hosts is on,
# which silently undoes the DNS scenario's /etc/hosts fault after a reboot.
install -d /etc/cloud/cloud.cfg.d
printf 'manage_etc_hosts: false\n' > /etc/cloud/cloud.cfg.d/99-plp-hosts.cfg
# and stop cloud-init entirely: it has finished its work by now, and a
# drop-in does not always beat the instance user-data.
touch /etc/cloud/cloud-init.disabled

# nginx is only used by an optional scenario; if that scenario is not active,
# keep it from serving a stray page the tickets never mention.
if [ ! -d "$HERE/scenarios/s1-website" ]; then
  systemctl disable --now nginx >/dev/null 2>&1 || true
fi

echo "### 2/5 accounts"
id candidate >/dev/null 2>&1 || adduser --disabled-password --gecos "PLP Candidate" candidate
usermod -aG sudo candidate
# Candidate needs full root for these tasks; the session is proctored and recorded.
echo 'candidate ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/candidate
chmod 0440 /etc/sudoers.d/candidate
echo "candidate:plp2026" | chpasswd   # CHANGE THIS per sitting

echo "### 3/5 command auditing (candidates are told about this)"
cat > /etc/profile.d/99-exam-audit.sh <<'AUD'
# Exam transcript. Candidates are informed that the session is recorded.
export HISTTIMEFORMAT="%F %T "
export HISTSIZE=100000 HISTFILESIZE=100000
export PROMPT_COMMAND='builtin history 1 | sed "s|^|$(date -Is) $(id -un) $(tty) |" >> /var/log/exam-audit.log 2>/dev/null; '"${PROMPT_COMMAND:-}"
AUD
# Order matters: an append-only file cannot be chowned or truncated, even by
# root, so clear the attribute first and set it last.
chattr -a /var/log/exam-audit.log 2>/dev/null || true
: > /var/log/exam-audit.log
chown root:root /var/log/exam-audit.log
chmod 0622 /var/log/exam-audit.log                      # users append, cannot read back
chattr +a /var/log/exam-audit.log 2>/dev/null || true   # append-only where the fs supports it

# s6 finishes by enabling ufw with default-deny egress. On a re-run that would
# block s5's wheelhouse download, so the firewall starts from off every time;
# s6's setup.sh owns the final state and runs last.
ufw --force disable >/dev/null 2>&1 || true

echo "### 4/5 scenario baselines"
install -d -m 0700 /var/lib/plp-exam
mkdir -p "$HERE/state"
bash "$HERE/bin/exam-ctl.sh" setup

echo "### 5/5 baseline health check"
bash "$HERE/vm/healthcheck.sh" || {
  echo; echo "!!! Baseline is not clean. Fix the setup scripts before arming." >&2; exit 1; }

cat <<'DONE'

Provisioning complete and the baseline is clean.

If you are driving this with ./plp (the normal way), it has already snapshotted
'golden' and will arm next. Nothing to do here.

Running provision.sh by hand instead? Then:
  1. Power off, snapshot as        golden
  2. bash bin/exam-ctl.sh arm      inject the faults
  3. bash bin/seal.sh              candidate bundle in, harness out
  4. Power off, snapshot as        armed
  5. After the sitting:            bash bin/score.sh
DONE
