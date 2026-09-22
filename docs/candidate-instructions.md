# Part B — instructions to candidates

**Time: 90 minutes.** Read this page first; it takes two minutes and it is
worth marks.

## Your machine

You have root on this virtual machine (`sudo` with no password). It is a
disposable clone — you cannot break anything that matters, so do not be timid.
It is **not** connected to any real network or to any real ISI system.

Log in as `candidate`.

## Your work

Three support tickets are in `~/tickets/`. They are independent; do them in any
order. Each describes a real fault, or several, on this machine.

Each ticket ends with **"How to check you have fixed it"** — the exact commands
and the output you should see. Run them. You should not have to guess whether
you are finished.

You are not expected to know all of this in advance. A fault you diagnose
correctly and explain, but cannot finish, is worth more than one you paper over.

## The rules

1. **Read each ticket fully, including the constraints.** Constraints such as
   "do not use `chmod 777`", "the firewall must stay on", "do not edit the
   script" are marked, and breaking them **loses** marks even if the symptom
   goes away. This is not a trick; it is the job.
2. **Keep `~/FIXLOG.md` up to date as you go.** For each fix: the symptom, the
   cause, exactly what you changed, how you *verified* it, and anything you left
   unfinished or are unsure about. This is worth 10 marks on its own. Write it
   as you go, not at the end — you will run out of time at the end.
3. **You may use any tool, including AI assistants, search, and your own
   notes.** You may not communicate with another person.
4. **Your screen and your shell commands are recorded.** We look at the
   recording to see *how* you worked, not to catch you out.
5. **There will be a short viva afterwards** about the work you did, with no
   devices. Be ready to explain any change you made and why.
6. If you genuinely destroy the machine, say so — tell the invigilator. We can
   reset a scenario. Saying so costs you almost nothing; hiding it costs you a
   lot.

## Things that are always true here

- `man`, `--help`, `journalctl`, and the logs under `/var/log` are all present.
- If a service will not start, something has already told you why.
- If two tools disagree with each other, both are probably right and your model
  of the problem is wrong.

Good luck.
