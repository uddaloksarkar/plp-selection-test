#!/usr/bin/env bash
# Runs every verify.sh and prints a marksheet. Also writes JSON to /var/log/plp-exam-score.json
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export EXAM_ROOT="${EXAM_ROOT:-$HERE}"
ALL=(s1-website s2-disk s3-permissions s4-dns s5-python s6-vpn s7-tunnel)
sel=("$@"); [ ${#sel[@]} -eq 0 ] && sel=("${ALL[@]}")
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 2; }

tmp=$(mktemp); grand_e=0; grand_t=0; json="["
for s in "${sel[@]}"; do
  v="$HERE/scenarios/$s/verify.sh"
  [ -x "$v" ] || continue
  echo "───────────────────────────────────────────────────────────────"
  echo "## $s"
  EXAM_ROOT="$EXAM_ROOT" bash "$v" | tee "$tmp"
  line=$(grep '^SCORE ' "$tmp" | tail -1)
  e=$(echo "$line" | awk '{split($3,a,"/"); print a[1]}')
  t=$(echo "$line" | awk '{split($3,a,"/"); print a[2]}')
  grand_e=$((grand_e + ${e:-0})); grand_t=$((grand_t + ${t:-0}))
  json="$json{\"scenario\":\"$s\",\"earned\":${e:-0},\"total\":${t:-0}},"
done
rm -f "$tmp"
json="${json%,}]"
echo "───────────────────────────────────────────────────────────────"
pct=0; [ "$grand_t" -gt 0 ] && pct=$(( grand_e * 100 / grand_t ))
printf 'PART-B TOTAL: %d / %d  (%d%%)\n' "$grand_e" "$grand_t" "$pct"
echo "Reminder: add the FIXLOG / viva marks from docs/scoring-sheet.md by hand."
printf '{"host":"%s","when":"%s","total":%d,"max":%d,"scenarios":%s}\n' \
  "$(hostname)" "$(date -Is)" "$grand_e" "$grand_t" "$json" > /var/log/plp-exam-score.json
