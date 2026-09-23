#!/usr/bin/env bash
# Produce the CANDIDATE-FACING bundle from this examiner repository.
#
# This is the single definition of "what a candidate is allowed to see".
# seal.sh calls it on the VM; run it by hand to inspect or print the pack.
#
#   bin/make-candidate-bundle.sh [outdir]      default: build/candidate-bundle
#
# Everything not listed in ALLOW below is examiner-only and never copied:
# setup.sh, break.sh, verify.sh, reset.sh, rubric.md, and all of docs/ except
# the candidate instructions.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$HERE/build/candidate-bundle}"

rm -rf "$OUT"
mkdir -p "$OUT/tickets"

# --- 1. the instructions ---------------------------------------------------
cp "$HERE/docs/candidate-instructions.md" "$OUT/00-READ-ME-FIRST.md"

# --- 2. the six tickets, renumbered so internal scenario ids do not leak ----
# every ticket carries the same heading; it is defined once, in
# docs/ticket-header.md, so changing the time limit or the marking note is
# a one-line edit that reaches all six.
HEADER="$HERE/docs/ticket-header.md"
[ -f "$HEADER" ] || { echo "missing $HEADER" >&2; exit 1; }

i=0
for d in "$HERE"/scenarios/*/; do
  s=$(basename "$d")                 # s1-website
  topic=${s#*-}                      # website
  i=$((i+1))
  n=$(printf '%02d' "$i")
  { cat "$HEADER"; echo; echo "---"; echo; cat "$d/ticket.md"; } > "$OUT/tickets/$n-$topic.md"
done

# --- 3. a combined copy for printing --------------------------------------
# The printable paper is a LaTeX document laid out like the ISI Computing
# Laboratory lab tests. It is authored in docs/exam-paper.tex and must be kept
# in step with the ticket files by hand -- the VM serves the Markdown, the
# invigilator hands out the PDF.
PAPER="$HERE/docs/exam-paper.tex"
if [ -f "$PAPER" ]; then
  cp "$PAPER" "$OUT/ALL-TICKETS.tex"
  if command -v pdflatex >/dev/null 2>&1; then
    ( cd "$OUT" && pdflatex -interaction=batchmode -halt-on-error ALL-TICKETS.tex >/dev/null 2>&1 \
        && pdflatex -interaction=batchmode -halt-on-error ALL-TICKETS.tex >/dev/null 2>&1 )
    rm -f "$OUT"/ALL-TICKETS.{aux,log,out,toc,fls,fdb_latexmk,synctex.gz,nav,snm,vrb,bbl,blg}
    [ -f "$OUT/ALL-TICKETS.pdf" ] || echo "note: pdflatex did not produce a PDF" >&2
  else
    echo "note: pdflatex not installed - ALL-TICKETS.tex not compiled" >&2
  fi
else
  echo "note: $PAPER missing - no printable paper in this bundle" >&2
fi

# --- 4. the FIXLOG the candidate fills in ---------------------------------
cat > "$OUT/FIXLOG.md" <<'TPL'
# FIXLOG

One entry per fix, written as you go. This is marked (10 marks): we look for
whether you separated the *cause* from the *symptom*, whether you verified, and
whether you were honest about what you did not finish.

Copy this block for each fix.

---

## <ticket number and name>

**Symptom:**   what the user saw / what you saw

**Cause:**     the actual defect, and the file or unit it was in

**Change:**    exactly what you changed

**Verified:**  the command you ran to prove it, and its result

**Left open:** anything unfinished, uncertain, or that someone else must confirm

---
TPL

# --- 5. leak check: nothing examiner-only may appear ----------------------
fail=0
ALLOW='^(00-READ-ME-FIRST\.md|ALL-TICKETS\.(tex|pdf)|FIXLOG\.md|tickets/[0-9]{2}-[a-z]+\.md)$'
while IFS= read -r rel; do
  [[ $rel =~ $ALLOW ]] || { echo "LEAK: unexpected file in bundle: $rel" >&2; fail=1; }
done < <(cd "$OUT" && find . -type f | sed 's|^\./||')

# strings that only ever occur in examiner material
for pat in 'Faults injected' 'What separates a strong candidate' 'Viva follow-ups' \
           'penalty ' 'verify\.sh' 'break\.sh' 'rubric' 'EXAM_ROOT' 'plp-exam-vm'; do
  if grep -rInE "$pat" "$OUT" >/dev/null 2>&1; then
    echo "LEAK: examiner material matched /$pat/ in the bundle:" >&2
    grep -rInE "$pat" "$OUT" >&2
    fail=1
  fi
done
[ "$fail" -eq 0 ] || { echo; echo "BUNDLE REJECTED — fix the above before using it." >&2; exit 1; }

echo "Candidate bundle written to: $OUT"
(cd "$OUT" && find . -type f | sed 's|^\./|  |' | sort)
echo
echo "Leak check passed: no examiner material in the bundle."
