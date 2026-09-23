#!/usr/bin/env bash
# Faults: (1) the IdentityFile line is gone from ~/.ssh/config, so ssh never
#             offers the key at all
#         (2) the private key is world-readable, so even once it is offered
#             ssh refuses to use it
# Both end in "Permission denied (publickey)". Only 'ssh -v' separates them:
# it shows whether a key was offered in the first place.
set -euo pipefail
[ -f /etc/plp-exam-vm ] || { echo "not an exam VM" >&2; exit 3; }

sed -i '/^[[:space:]]*IdentityFile[[:space:]]/d' /home/candidate/.ssh/config
chmod 0644 /home/candidate/.ssh/id_acmu

# --- assert the faults took --------------------------------------------------
grep -qE '^[[:space:]]*IdentityFile' /home/candidate/.ssh/config \
  && { echo "s8 break FAILED: IdentityFile is still in the config" >&2; exit 1; }
[ "$(stat -c %a /home/candidate/.ssh/id_acmu)" = 644 ] \
  || { echo "s8 break FAILED: key permissions were not loosened" >&2; exit 1; }
runuser -l candidate -c 'ssh -o BatchMode=yes -o ConnectTimeout=5 acmulab true' 2>/dev/null \
  && { echo "s8 break FAILED: ssh acmulab still works" >&2; exit 1; }

echo "s8 armed"
