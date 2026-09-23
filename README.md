# PLP selection examination — Part B (practical)

A hands-on troubleshooting exam. Each candidate gets their own disposable Ubuntu
VM with **three broken help-desk tickets** in it; they diagnose and repair them;
the marking is automatic, check by check.

---

## Set up a VM in two commands

On a **Linux** machine (Ubuntu/Debian) with internet access for the first run:

```bash
git clone https://github.com/uddaloksarkar/plp-selection-test.git/plp-selection-test.git && cd plp-selection-test
./plp up
```

That's it. `./plp up` runs unattended for **about 15–20 minutes** and ends with:

```
  Ready for the candidate.
  ...
      ssh candidate@192.168.56.10        password: plp2026
```

It installs VirtualBox and the other tools it needs if they are missing (asks for
`sudo` once), downloads the Ubuntu cloud image (~600 MB, only the first time),
builds the VM, checks every scenario works, breaks them, removes the answers,
and takes the VM offline. You never see an installer or a VM window.

**Check it any time:**

```bash
./plp status
```

A ready VM shows `network hostonly`, `harness removed`, `tickets 4 files`.

### Needs

| | |
|---|---|
| OS | Linux with `apt` (tested on Ubuntu 24.04). Not macOS/Windows. |
| Disk / RAM | ~30 GB free, 8 GB RAM (the VM uses 4 GB, 2 CPUs) |
| Network | internet for the first `./plp up` only; the exam itself runs offline |
| Rights | a normal user with `sudo` (only needed to install VirtualBox) |

Optional: `cp plp.conf.example plp.conf` to change the candidate password, VM
size or address before `./plp up`. Every setting has a working default.

---

## Running a sitting

| When | Command |
|---|---|
| Candidate sits down | they run `ssh candidate@192.168.56.10` (password `plp2026`) — tickets are in `~/tickets` |
| Time is up | `./plp score` → marksheet in `marks/` |
| Next candidate | `./plp rearm` → pristine again in ~1 minute |
| Printed paper | [`docs/exam-paper.pdf`](docs/exam-paper.pdf) |
| Finished for good | `./plp destroy` |

Proctoring, timings and what to do if something goes wrong mid-exam:
**[docs/proctor-runbook.md](docs/proctor-runbook.md)**.

> **Examiners only:** the answers are in [`SOLUTION.md`](SOLUTION.md) and each
> scenario's `rubric.md`. Hand candidates the PDF or the VM — never this repo.

### If something goes wrong

| Symptom | Fix |
|---|---|
| `ssh` says **REMOTE HOST IDENTIFICATION HAS CHANGED** | normal after a rebuild: `ssh-keygen -R 192.168.56.10` |
| `./plp up` stops with an error | read the last `ERROR:` line; `./plp doctor` re-checks the host |
| VirtualBox kernel module will not load | Secure Boot: sign/enroll the `vboxdrv` module, or disable Secure Boot |
| Want a completely fresh VM | `./plp destroy` then `./plp up` |

Everything else, step by step: **[SETUP.md](SETUP.md)**.

---

## The paper

Three tickets, 90 minutes, in any order. Each ticket is split into **independent
parts** — one fault each, marked on its own, with the commands to check it.

| # | Ticket | What it tests |
|---|---|---|
| 1 | [Disk full on the file server](scenarios/s2-disk/ticket.md) | `df` vs `du`, a deleted-but-open file, inode exhaustion |
| 2 | [Shared project folder unusable](scenarios/s3-permissions/ticket.md) | groups, setgid, file modes, sudoers, ACLs |
| 3 | [Cannot log in to the lab server](scenarios/s8-ssh/ticket.md) | ssh key login: the alias, and the key's permissions |

Every ticket also scores the tempting shortcut — `chmod 777`, reformatting a
disk, putting the auditor in the group, turning off sshd's `StrictModes`,
opening a firewall — as a **negative**. That is the point of the paper.

Marks per ticket and part are printed on the paper; how Part B combines with
the written paper, FIXLOG and viva is in
[docs/scoring-sheet.md](docs/scoring-sheet.md). Why it is designed this way —
including running it fairly when every candidate has an LLM in their pocket —
is in [docs/exam-design.md](docs/exam-design.md).

Four more scenarios (web server, DNS, Python environment, VPN) are complete but
not in the current paper: [scenarios-optional/](scenarios-optional/).

---

## For maintainers

**Safety.** Every script that breaks things refuses to run unless
`/etc/plp-exam-vm` exists, and only the VM build creates that marker. Never run
the scenario scripts on a machine you care about.

**Why a real VM, not Docker.** Ticket 1 needs loop devices and `mkfs`; ticket 3
builds a network namespace with its own firewall and reconfigures sshd. In a
container those reach the host kernel.

**The invariant.** On an unbroken VM every check must pass (full marks).
`./plp provision` enforces it before anything is armed; if a check fails on a
healthy box, the bug is in the harness, not the candidate.

**Changing a scenario.** Edit its files, then:

| You changed | Run |
|---|---|
| `ticket.md`, `break.sh`, `verify.sh` | `./plp arm` (after restoring the `golden` snapshot) |
| `setup.sh` | `./plp provision && ./plp arm` — `arm` refuses a stale baseline |
| anything, and want certainty | `./plp destroy && ./plp up` |

Keep `docs/exam-paper.tex` in step with the tickets by hand; build it with
`pdflatex -output-directory=docs docs/exam-paper.tex`.

Each scenario directory holds:

| file | for | purpose |
|---|---|---|
| `ticket.md` | **candidate** | the help-desk ticket |
| `setup.sh` | examiner | builds the healthy baseline |
| `break.sh` | examiner | injects the faults, and checks they took |
| `verify.sh` | examiner | marks the work, one check per part |
| `reset.sh` | examiner | rebuild + re-break one scenario mid-exam (`./plp reset <scenario>`) |
| `rubric.md` | examiner | faults, what strong work looks like, viva questions |

```
plp                  the one entry point: up | status | score | rearm | destroy
plp.conf.example     VM size, exam address, candidate password (all optional)
lib/steps/           one file per stage (doctor, image, vm, provision, arm, ...)
lib/common.sh        config, logging, ssh and snapshot helpers
lib/checks.sh        the PASS / FAIL / PENALTY scoring primitives
bin/                 on-VM control: exam-ctl.sh, score.sh, seal.sh, candidate bundle
vm/                  provision.sh (builds the VM), healthcheck.sh (the invariant)
scenarios/           the three tickets in the paper
scenarios-optional/  four more, complete but not in use
docs/                printable paper, design notes, runbook, marksheet, viva bank
SOLUTION.md          the answer key (examiners only)
SETUP.md             the full build, stage by stage
```
