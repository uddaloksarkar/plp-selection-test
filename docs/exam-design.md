# PLP selection — examination design

Role: Project Linked Person supporting **software, hardware and web** for the
unit. The person will spend their day on other people's broken machines, not on
greenfield code.

---

## 1. The problem the LLM era creates

Every question whose answer is a *recall of a procedure* is now free. A
candidate with a phone can produce a competent-sounding answer to "how do I fix
a full disk" in four seconds. If your paper tests recall, you will rank
candidates by their typing speed.

What has **not** become free, and what this job actually needs:

| Still scarce | Why an LLM doesn't supply it |
|---|---|
| Deciding *which* of five plausible causes applies **to this box** | The model cannot see the box |
| Reading an error message and believing it | Requires attention, not knowledge |
| Knowing when the confident answer is wrong | Requires having been burned |
| Refusing the destructive shortcut under time pressure | Requires judgement and honesty |
| Verifying a fix instead of declaring one | Requires discipline |
| Explaining it to a Head of Department in two sentences | Requires being a person |

So the exam is built to reward those six things and to make recall almost
worthless.

### Our position on candidates using AI during the exam

**Recommended: allow it openly in Part B, ban it in Part A, record the screen.**

Reasoning: the successful candidate *will* use an LLM on the job from day one.
Pretending otherwise selects for people who lie about their tools. What you
actually need to know is whether they can tell a good answer from a
confident-sounding wrong one. So:

- **Part A** — devices surrendered, paper and pen, invigilated. Tests whether
  the fundamentals are in their head.
- **Part B** — hands-on, on a VM, **any tool allowed, including AI**, screen
  recorded. Tests whether they can drive a real machine to a verified fix.
- **Viva** — 10–15 minutes at the end of Part B, on their own work, no devices.
  This is where borrowed answers fall apart, and it is why allowing AI in
  Part B costs you nothing.

If your panel prefers a no-AI exam, the Part B VM works completely offline —
just don't attach a network. Everything scenario-side is local. Keep the viva
either way; it is the single most informative fifteen minutes of the day.

### Design rules used throughout Part B

1. **Every scenario has more than one fault**, in different layers. A single
   pasted command never completes a scenario.
2. **The obvious shortcut is scored negatively.** `chmod 777`, `ufw disable`,
   `pip install --break-system-packages`, hard-coding names into `/etc/hosts`,
   rebooting to clear a leak — each makes the symptom vanish and each loses
   marks. An LLM asked a leading question will frequently suggest exactly these.
3. **Facts live only on the box.** The correct VPN key, the wheelhouse path, the
   names in the zone, the "safe to delete" note — none of it can be guessed.
4. **Scoring is automated and per-check**, so partial credit is real and
   grading two dozen candidates is uniform and fast.
5. **The paper is deliberately longer than the time.** Triage is part of the
   assessment.

---

## 2. Shape of the examination

| | Part | Duration | Marks |
|---|---|---|---|
| A | Written / oral, no devices | 45 min | 30 |
| — | Break, VM handout | 15 min | — |
| B | Hands-on scenarios on a VM | 90 min | 40 (automated) + 15 (FIXLOG) |
| C | Viva on their own Part B work | 15 min per candidate | 15 |
| | **Total** | | **100** |

---

## 3. Part A — written, 45 minutes, no devices (30 marks)

Four sections. Nothing here asks for a command's exact syntax.

### A1. Read the output (12 marks)

Hand them printed terminal transcripts and ask two questions of each: *what is
wrong* and *what would you run next*. Suggested six, two marks each:

1. `df -h` showing 8% used next to `touch: cannot touch 'x': No space left on device`.
   *(inode exhaustion — expect `df -i`)*
2. `systemctl status nginx` with `Job for nginx.service failed ... see journalctl`
   plus the journal line `duplicate default server for 0.0.0.0:80`.
3. `ls -l` showing `-rw-------  1 arnab arnab  notes.md` and a user in group
   `acmu` getting Permission denied.
4. A `ping` that resolves instantly to the wrong address, with `/etc/hosts`
   printed beside it.
5. A Python traceback ending `ImportError` where `numpy.__file__` points
   somewhere under `/opt/legacy`.
6. `wg show` output with `latest handshake` absent entirely.

These are the same fault families as Part B. A candidate who reads output well
in A1 and then flails in B was reading, not thinking — useful signal.

### A2. Critique the confident answer (8 marks)

**This is the LLM-era question.** Give them a ticket and a plausible,
fluent, *wrong* answer, presented as "a colleague's suggestion". Ask: what in
this is wrong, what is risky, and what would you do instead?

Example to hand out:

> **Ticket:** Users in the `acmu` group can't write to the shared project
> folder.
> **Suggested fix:** "Run `sudo chmod -R 777 /srv/projects/acmu`. This gives
> everyone full access and will immediately resolve the permission errors. You
> can also add the users to the `sudo` group so they don't hit this again."

Full marks require naming: world-writable exposes the data to every account on
the machine; `-R` also strips the setgid bit so the *next* file will break
again; `sudo` group membership is a privilege escalation unrelated to the
problem; and the correct fix is group ownership + `2770` + group membership.

Write two of these. The second one should be *subtly* wrong rather than
obviously wrong — e.g. an answer that fixes the symptom correctly but silently
disables a security control.

### A3. Explain it to the user (6 marks)

> The department website was down for three hours this morning. Write the email
> the Head of Department receives at 13:00. Six sentences maximum. She is not
> technical, she is annoyed, and she wants to know it won't happen again.

Marks for: plain language, no blame, what was wrong, what was done, what
prevents recurrence, and an honest statement of what is still uncertain. This
predicts on-the-job performance better than any technical question on the paper,
and it is very hard to fake under invigilation.

### A4. Hardware and the physical estate (4 marks)

The role covers hardware; make it concrete and local, not trivia.

- A desktop in the computing lab powers on, fans spin, no display, no POST beep.
  List the order you check things and why that order.
- A user says their machine "has become very slow since the power cut."
  What do you look at, in what order? *(Expect: SMART data, filesystem errors in
  `dmesg`, thermal/dust, swap thrashing, and asking what changed.)*
- You are asked to dispose of four retired machines that held student records.
  What do you do with the disks?

---

## 4. Part B — hands-on (in this repository)

| # | Scenario | Domain | Raw |
|---|---|---|---|
| 1 | Disk space | Storage | 14 |
| 2 | User permissions | Linux | 16 |
| 3 | SSH key login | SSH / permissions | 10 |

Three scenarios on one VM per candidate, 90 minutes, all three armed at once,
candidate picks the order. Automated scoring out of 40, counted directly.

The paper was cut from six scenarios to three deliberately. Six rewarded
skimming; three give a candidate room to diagnose properly, and diagnosis is
what the post actually needs. The three retained cover the fault families this
role meets weekly — storage, permissions, remote access — and each still
carries two to four independent faults in different layers. The other three
(web service, Python environment, VPN/firewall) are complete and kept in
`scenarios-optional/` if a future panel wants them.

Every ticket now ends with **"How to check you have fixed it"** — the exact
commands, with the output to expect. Candidates should not have to guess whether
they are done, and it makes partial credit legible to them as they work.

### The FIXLOG (15 marks)

Every candidate writes `~/FIXLOG.md` as they go. One entry per fix:

```
## S1 — website
Symptom:   nginx dead, `nginx -t` reports duplicate default server
Cause:     /etc/nginx/sites-enabled/zz-legacy.conf, second listen 80 default_server
Change:    removed the symlink (kept the file), restored docroot to www-data 0755
Verified:  curl -H 'Host: acmu.isi.local' localhost -> page returns; systemctl is-enabled nginx
Left open: the legacy file says "do not delete" — needs confirming with its author
```

Mark on: is the *cause* distinguished from the *symptom*; is there a
verification step; is anything honestly flagged as unfinished or uncertain. A
candidate who scores 80/100 automated with an empty FIXLOG is a worse hire than
one who scores 55 with a clear one, and the marks should be able to express that.

### The viva (15 marks)

Per-scenario questions are in each `rubric.md` and collected in
`docs/viva-questions.md`. Run it at the machine, with their own FIXLOG open,
devices away. Three things to probe:

1. **"Show me how you proved it."** Anyone can assert a fix.
2. **"Why not the shortcut?"** Ask directly about the shortcut they *didn't*
   take — or the one they did. An honest "I took the quick path because I was
   running out of time, and here's what I'd do properly" scores well. Pretending
   the quick path was correct does not.
3. **"Where did this answer come from?"** If they used an LLM, ask what it got
   wrong. The good candidates always have an answer to this and enjoy the
   question. Someone who claims it was right about everything either didn't use
   it or didn't check it.

---

## 5. What to actually select on

After a full sitting you will have, per candidate, an automated score, a
FIXLOG, a screen recording and fifteen minutes of conversation. Rank on:

1. **Does not make things worse.** A candidate who scores 70 with two `−6`
   penalties is a liability in a live environment. Weight the penalties heavily
   in discussion, not just in arithmetic.
2. **Verifies.** Look for `curl`, `sudo -u`, `getent`, a second `systemctl
   status` in the recording — evidence they checked their own work.
3. **Reads before typing.** The recording shows this plainly. The best
   candidates spend the first three minutes of each scenario reading and the
   next two fixing.
4. **Says "I don't know" cleanly** in the viva. In this role that sentence,
   said early, is worth more than any command.
