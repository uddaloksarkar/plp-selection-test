# Per-candidate scoring sheet

Candidate: ________________________  Date: __________  Panel: ______________

## Part A — written (30)

| | | max | given |
|---|---|---|---|
| A1 | Read the output (6 × 2) | 12 | |
| A2 | Critique the confident answer | 8 | |
| A3 | Explain it to the user | 6 | |
| A4 | Hardware and the estate | 4 | |
| | **Part A** | **30** | |

## Part B — automated (45)

Raw score from `bin/score.sh`, out of 50, scaled to 45 (`raw / 50 * 45`).

| scenario | raw | max |
|---|---|---|
| s2-disk | | 16 |
| s3-permissions | | 18 |
| s4-dns | | 16 |
| penalties (negative) | | |
| **raw total** | | **50** |
| **scaled → /45** | | **45** |

Penalties incurred (list them — discuss these in the panel even when the total
looks healthy):

_____________________________________________________________________

## Part B — FIXLOG (10)

| | max | given |
|---|---|---|
| Cause distinguished from symptom | 3 | |
| Verification step recorded for each fix | 3 | |
| Honest about what is unfinished / uncertain | 2 | |
| Readable by the next person on shift | 2 | |
| **FIXLOG** | **10** | |

## Part C — viva (15)

| | max | given |
|---|---|---|
| Can explain the *mechanism* of at least two faults | 5 | |
| Can justify why the shortcut was refused (or honestly own taking it) | 4 | |
| Says "I don't know" cleanly where appropriate | 3 | |
| Communication — would you put them in front of a HoD? | 3 | |
| **Viva** | **15** | |

## Total: ______ / 100

### Panel notes

Observed working style (from the recording — reads first? verifies? panics?):

_____________________________________________________________________

_____________________________________________________________________

### Suggested bands

| Band | Meaning |
|---|---|
| 75+ | Strong. Would leave them alone with a production box. |
| 60–74 | Appointable. Competent, needs a review habit. |
| 45–59 | Borderline. Only with supervision and a named mentor. |
| < 45, **or any two heavy penalties** | Do not appoint for this role. A candidate who scores well by disabling security controls is the specific failure mode this exam exists to catch. |
