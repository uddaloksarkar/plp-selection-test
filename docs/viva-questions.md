# Viva bank (Part C)

Fifteen minutes, at the machine, with their own `FIXLOG.md` open and devices
away. Pick from the scenarios they actually attempted. Aim for three or four
questions, in depth, not twelve shallow ones.

## Openers (always ask two of these)

- "Which ticket did you pick first, and why? Which did you abandon, and why?"
- "Which one cost you the most time? What were you assuming that turned out to
  be false?"
- "Take any fix in your log and show me, right now, how you proved it worked."
- "Did you use an AI assistant? Good — what did it get wrong?"
  *(Expect specifics: it suggested the shortcut, it assumed a distro, it
  hallucinated a path, it gave a fix for a symptom I didn't have. "It was right
  about everything" means they did not check.)*
- "You are twenty minutes in, nothing is working, and the HoD is standing
  behind you. What do you actually do?"

## Per scenario

**S1 — website**
- Show me how you proved the fix, not just that the page loads.
- The legacy config said "do not delete". What did you do, and who do you tell?
- What is the difference between `stop` and `disable`, and why did it matter here?

**S2 — disk**
- You restarted the collector and space came back. What exactly was holding it?
- `du` said 300 MB, `df` said full. Why is that not a contradiction?
- The spool had free space and still said "No space left on device". Explain.
- How do you stop all three of these recurring next month?

**S3 — permissions**
- What does the `2` in `2770` do, and what breaks silently without it?
- Why an ACL for the auditor rather than adding him to the group?
- You added buddhadev back to the group and his shell still says denied. Why?
- Why `visudo -f` and not `vim`? What happens if you get sudoers wrong?

**S4 — DNS** (optional scenario)
- Walk me from `ping www.isi.local` to the first packet on the wire.
- Why did exactly one name answer, and answer wrongly?
- You could have fixed all of it with `/etc/hosts` in thirty seconds. Why didn't you?
- How would you have found the `nsswitch.conf` fault with no logs at all?

**Q3 — ssh key login**
- Both faults printed the same error. How did you tell them apart?
- Why does ssh care about the mode of *your own* private key? Whose problem is it?
- What would `Connection refused` have meant instead, and where would you look?
- Ten machines to set this up on tomorrow — what do you do differently?
  does a colleague's request travel?
- In `-R 0.0.0.0:8080:localhost:8888`, whose `localhost` is that?
- The key was right and sshd still refused it. Why does sshd care who can write
  `authorized_keys`, and why is `StrictModes no` the wrong fix?
- `curl localhost:8080` worked on the gateway but not from anywhere else. What
  was listening where, and which end of the `-R` is which?

**S5 — Python**
- Why did it work for you as root but not for the analyst?
- Put `sys.path` on the board for that script. Which entry wins, and why?
- The user had already tried `pip install numpy`. What would that have done if
  it had succeeded, and why is it the wrong instinct?
- How would you make this job survive next year's OS upgrade?

**S6 — VPN and firewall**
- There was no error message anywhere. How did you decide where to look?
- Explain `AllowedIPs` to me as though I were a new student.
  *(Full answer: it is both the routing entry for outbound traffic and the
  cryptokey-routing filter for inbound — packets arriving from that peer with a
  source outside the range are dropped. Most candidates give only the first half;
  so does most AI-generated text.)*
- You could have run `ufw disable` and been done in ten seconds. Why was that
  the wrong answer — and what do you say if your supervisor tells you to do it
  anyway at 5pm on a Friday?

## Closing question (ask everyone, it ranks well)

> "A user tells you their problem is urgent and asks you to do something you
> think is a bad idea. Walk me through the conversation."
