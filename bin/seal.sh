#!/usr/bin/env bash
# Turn the armed VM into a candidate-facing machine:
# install the candidate bundle into /home/candidate, then delete the examiner
# harness from this VM. Your laptop keeps the authoritative copy of the repo
# and you rsync it back after the sitting to score.
#
# Run AFTER `exam-ctl.sh arm`.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 2; }
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
id candidate >/dev/null 2>&1 || { echo "no 'candidate' user — run provision.sh first" >&2; exit 2; }

# One definition of what a candidate may see. Fails closed if anything leaks.
TMP=$(mktemp -d)
bash "$HERE/bin/make-candidate-bundle.sh" "$TMP/bundle"

install -d -o candidate -g candidate -m 0755 /home/candidate/tickets
cp -a "$TMP/bundle/tickets/." /home/candidate/tickets/
install -o candidate -g candidate -m 0644 "$TMP/bundle/00-READ-ME-FIRST.md" /home/candidate/tickets/
install -o candidate -g candidate -m 0644 "$TMP/bundle/FIXLOG.md"           /home/candidate/FIXLOG.md
chown -R candidate:candidate /home/candidate/tickets
rm -rf "$TMP"

echo
echo "Installed for the candidate:"
find /home/candidate/tickets /home/candidate/FIXLOG.md -type f | sed 's|^|  |' | sort
echo
read -r -p "Now DELETE the examiner harness at $HERE from this VM? (yes/no) " a
[ "$a" = yes ] || { echo "Left in place. The VM still contains the answers — do not hand it to a candidate."; exit 1; }
echo "Harness removed. The candidate sees only ~/tickets and ~/FIXLOG.md."
# exec, so bash is not reading this file while it is being deleted
exec rm -rf "$HERE"
