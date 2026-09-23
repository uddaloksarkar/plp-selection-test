# Part B — proctor runbook

Running the sitting. Building the environment is **[../SETUP.md](../SETUP.md)**;
the reasoning behind the paper is **[exam-design.md](exam-design.md)**.

## Before the day

**One machine, one VM, one candidate.** Every lab computer is prepared
independently — whoever sits at it can run this, in parallel with the others.

```bash
cp plp.conf.example plp.conf     # set CAND_PASSWORD for this sitting
./plp up                         # ~15 min, unattended
./plp status                     # running, reachable, harness 'removed'
```

Then smoke-test it — [SETUP.md](../SETUP.md) section 4 lists the commands and
the broken behaviour each must show. A fault that failed to arm is invisible
until a candidate is in front of it.

Set `CAND_PASSWORD` **per sitting**. The default ships in the repository, and a
password that carries between sittings lets a later candidate into an earlier
one's machine.

### Pre-flight checklist, per machine

- [ ] Provisioning ended with `Baseline clean.`
- [ ] Smoke test passed — all three scenarios showing their symptoms
- [ ] `./plp status` shows harness `removed`
- [ ] `ssh candidate@192.168.56.10` works with this sitting's password
- [ ] Screen recording configured on the host desktop
- [ ] Printed pack ready if you are handing out paper:
      `build/candidate-bundle/ALL-TICKETS.md`

### How the candidate works

They open a terminal on the lab machine and `ssh candidate@192.168.56.10`.
Everything happens inside the VM, so nothing they type can damage the lab
machine, and the VM has no route to the internet.

## On the day

| Time | What |
|---|---|
| 0:00 | Part A, 45 min, devices surrendered |
| 0:45 | Break; hand out the ssh line, the password, and `candidate-instructions.md` |
| 1:00 | Part B starts (90 min). Read the Constraints rule **aloud**: breaking one loses marks even when the symptom clears. |
| 1:05 | Start screen recording on each station |
| 2:30 | Part B ends. Candidates stop typing; collect `FIXLOG.md` |
| 2:35 | Vivas, 15 min each, in parallel across panel members |

### During

- Walk the room. What you see in the first ten minutes — who reads, who types
  immediately — is worth noting on the sheet.
- If a candidate asks a clarifying question about a ticket, answer it, and give
  the same answer to everyone.
- If a candidate wedges a scenario beyond recovery, you can reset just that one
  (see below). Note it on their sheet; it costs them the time, not the marks.

### Resetting one scenario mid-exam

```bash
./plp reset s2-disk
```

That rebuilds and re-arms only that scenario, only on that VM, and removes the
harness again afterwards.

## Scoring after the sitting

With the candidate logged out, and the VM still running:

```bash
./plp score
```

It pushes the harness back, runs every `verify.sh`, and collects into `marks/`,
timestamped:

- `marks/<stamp>.txt` — per-check PASS / FAIL / PENALTY and the Part B total
- `marks/<stamp>-fixlog.md` — the candidate's FIXLOG
- `marks/<stamp>-audit.log` — their command transcript

For a second candidate on the same machine, score first, then `./plp rearm`.

Add the screen recording, then fill in [scoring-sheet.md](scoring-sheet.md) per
candidate.

## Notes and gotchas

- **Do not score a VM the candidate is still logged into** — a running shell can
  hold files open and skew the disk checks.
- Do not stop services before scoring: the disk scenario's `s2.leak` check looks
  for the collector's held file; stopping the collector releases it, which
  would award those 5 marks to a candidate who never found the leak.
- The VPN scenario's `s6.handshake` check wants a handshake inside 180 seconds.
  `PersistentKeepalive` keeps it fresh as long as the tunnel is genuinely up.
- If you re-run `score.sh` twice, that is fine; all checks are read-only except
  the permission ones, which create and remove their own temporary files.
