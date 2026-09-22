# S5 — Python environment (16 marks)

| id | marks | what it checks |
|---|---|---|
| s5.report | 6 | the real command produces the byte-exact expected line |
| s5.venv | 2 | `sys.prefix` is the venv — it was genuinely repaired |
| s5.numpysrc | 2 | numpy comes from the venv, not the legacy tree |
| s5.shadow | 2 | the rogue `csv.py` removed |
| s5.pypath | 2 | the global `PYTHONPATH` export removed |
| s5.syspy | 2 | nothing was installed into the system interpreter |
| s5.penown | −4 | venv rebuilt as root |
| s5.pensrc | −8 | edited the script or the data to fake the output |

## Faults injected
1. `.venv/pyvenv.cfg` `home =` points at `/opt/python-3.9/bin` and `.venv/bin/python` is a dangling symlink to `/usr/bin/python3.9`. Fix: recreate the venv and reinstall from `requirements.txt` **off the wheelhouse** (`pip install --no-index --find-links /opt/wheelhouse -r requirements.txt`).
2. `/etc/profile.d/zz-legacy-pythonpath.sh` exports `PYTHONPATH=/opt/legacy/pylibs`, which contains a `numpy` stub that raises `ImportError`. `PYTHONPATH` wins over site-packages, so even a perfectly rebuilt venv still fails — **and only in a login shell**, which is why "it works when I run it from here" is a trap.
3. `csv.py` sitting in the script's own directory shadows the stdlib `csv`, because `sys.path[0]` is the script directory.
4. `/etc/pip.conf` points at a dead internal index, so every `pip install` hangs then fails — the candidate must find the wheelhouse or pass `--no-index`.

## What separates a strong candidate
- Reads the traceback. Each fault names itself if you read the last line.
- Uses `python -c 'import numpy; print(numpy.__file__)'` to find *which* numpy is loading, rather than reinstalling.
- Understands `sys.path` ordering well enough to explain fault 2 and fault 3 — this is the single most LLM-resistant item in the paper, because the answer depends on files only present on this box.
- Rebuilds the venv **as `analyst`**, not with `sudo`.
- Does not reach for `--break-system-packages` after being told not to.

## Viva follow-ups
- "Why did the same command work for you as root but not for the analyst?"
- "Put `sys.path` on the whiteboard for that script. Which entry wins?"
- "The user had already run `pip install numpy`. What would that have done if it had succeeded, and why is it the wrong instinct?"
- "How would you make this job reproducible so that next year's upgrade doesn't break it?" (pinned `requirements.txt`, venv rebuilt from the wheelhouse in a unit/cron, or a container.)
