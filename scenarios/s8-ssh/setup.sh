#!/usr/bin/env bash
# Baseline: the candidate can log in to the lab server account over ssh with a
# key and no password. The "lab server" is this machine on its host-only
# address; that needs no second host and behaves exactly like a remote one.
set -euo pipefail
SRV_IP="${PLP_EXAM_IP:-192.168.56.10}"

id acmusrv >/dev/null 2>&1 || useradd -m -s /bin/bash acmusrv
passwd -l acmusrv >/dev/null                     # key-only account

install -d -m 0700 -o candidate -g candidate /home/candidate/.ssh
if [ ! -f /home/candidate/.ssh/id_acmu ]; then
  runuser -u candidate -- ssh-keygen -t ed25519 -N '' -q \
      -C "candidate@acmulab" -f /home/candidate/.ssh/id_acmu
fi
chown candidate:candidate /home/candidate/.ssh/id_acmu*
chmod 0600 /home/candidate/.ssh/id_acmu
chmod 0644 /home/candidate/.ssh/id_acmu.pub

install -d -m 0700 -o acmusrv -g acmusrv /home/acmusrv/.ssh
install -m 0600 -o acmusrv -g acmusrv /home/candidate/.ssh/id_acmu.pub \
        /home/acmusrv/.ssh/authorized_keys

# Something worth finding once you are in.
install -d -m 0755 -o acmusrv -g acmusrv /home/acmusrv/jobs
printf 'nightly extract — run after the survey upload\n' > /home/acmusrv/jobs/README
chown acmusrv:acmusrv /home/acmusrv/jobs/README

# StrictHostKeyChecking is off on purpose: a disposable exam machine, and a
# host-key prompt would block a non-interactive check.
cat > /home/candidate/.ssh/config <<CONF
Host acmulab
    HostName $SRV_IP
    User acmusrv
    Port 22
    IdentityFile ~/.ssh/id_acmu
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
CONF
chown candidate:candidate /home/candidate/.ssh/config
chmod 0600 /home/candidate/.ssh/config
echo "s8 baseline ready"
