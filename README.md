# PLP selection examination — Part B harness

Hands-on troubleshooting examination for a Project Linked Person supporting
software, hardware and web services. Six faults are injected into a disposable
Ubuntu VM; candidates diagnose and repair them; scoring is automated and
per-check so partial credit and penalties are uniform across candidates.

The reasoning behind the design — including how to run this fairly when every
candidate has an LLM in their pocket — is in **[docs/exam-design.md](docs/exam-design.md)**.

## Safety

Every destructive script refuses to run unless `/etc/plp-exam-vm` exists. That
marker is created only by `vm/provision.sh --i-know-this-is-a-disposable-vm`.
**Never run these on a machine you care about.**

## Quick start

**One machine, one VM, one candidate.** Every lab computer runs this once:

```bash
cp plp.conf.example plp.conf     # set CAND_PASSWORD for the sitting
./plp up                         # ~15 min, unattended
```

The candidate then sits at that computer and works inside the VM:

```bash
ssh candidate@192.168.56.10
```

Afterwards: `./plp score` (marks into `marks/`), `./plp rearm` (pristine again
for the next candidate), `./plp destroy`.

No Ubuntu installer, no VM console, no keystrokes into a VM window — it builds
from the official Ubuntu cloud image with cloud-init, and finishes by putting
the VM on an offline host-only network at a fixed address. Full detail in
**[SETUP.md](SETUP.md)**.

## What it is

A real VM per candidate machine, with six faults injected and the answers
removed. `./plp` handles the whole lifecycle; running the sitting itself is
**[docs/proctor-runbook.md](docs/proctor-runbook.md)**, and the reasoning behind
the paper is **[docs/exam-design.md](docs/exam-design.md)**.

> A real VM is required, not a container: s2 needs loop devices and `mkfs`, s6
> loads WireGuard and manipulates netfilter, and s4 replaces the system
> resolver — in a container those reach the host kernel.

## The scenarios

| # | Directory | Ticket | Domain | Marks |
|---|---|---|---|---|
| 1 | [scenarios/s2-disk/](scenarios/s2-disk/) | Disk full on the file server | Storage | 16 |
| 2 | [scenarios/s3-permissions/](scenarios/s3-permissions/) | Shared folder unusable | Linux | 18 |
| 3 | [scenarios/s4-dns/](scenarios/s4-dns/) | Campus names stopped resolving | Networking | 16 |

Three more — web service, Python environment, VPN/firewall — are complete but
held back in [scenarios-optional/](scenarios-optional/); see the README there.

Each scenario directory contains:

| file | audience | purpose |
|---|---|---|
| `setup.sh` | examiner | builds the healthy baseline |
| `break.sh` | examiner | injects the faults |
| `verify.sh` | examiner | scores the candidate's work, check by check |
| `reset.sh` | examiner | rebuild + re-arm a single scenario mid-exam |
| `ticket.md` | **candidate** | the help-desk ticket they are given |
| `rubric.md` | examiner | faults injected, what strong work looks like, viva questions |

Every scenario carries **two to four independent faults in different layers**, each ends with the exact commands to verify the fix,
and every scenario scores the obvious shortcut — `chmod 777`, `ufw disable`,
`--break-system-packages`, hard-coding into `/etc/hosts`, reformatting — as a
**negative**. That is the point of the paper.

## Design invariant

On a pristine baseline, **every check must pass**:

```bash
bash vm/healthcheck.sh     # must end with "Baseline clean."
```

`provision.sh` enforces this. If a check fails on an unbroken box, the bug is in
the harness, not in the candidate — fix it before arming.

## Repository layout

```
plp                  one entry point: up | status | score | rearm | destroy
plp.conf.example     VM size, exam address, candidate password
lib/steps/           one file per stage, each runnable alone
lib/common.sh        logging, config, ssh helpers

bin/exam-ctl.sh                setup | health | arm | score | reset, on the VM
bin/score.sh                   runs every verify.sh, marksheet + JSON
bin/seal.sh                    candidate bundle in, examiner harness out
bin/make-candidate-bundle.sh   the candidate-facing pack, with a leak check
lib/checks.sh                  the PASS/FAIL/PENALTY scoring primitives

vm/provision.sh      one-shot build of the exam VM
vm/healthcheck.sh    the baseline invariant
SETUP.md             end-to-end environment build (start here)
docs/                exam design, candidate instructions, runbook, marksheet, viva bank
scenarios/           the three active scenarios
scenarios-optional/  three more, complete but not in the current paper
```

## Marks

Part B automated total is 100 raw, scaled to 45 of a 100-mark examination.
The rest: Part A written 30, FIXLOG 10, viva 15.
See [docs/scoring-sheet.md](docs/scoring-sheet.md).
