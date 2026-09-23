# TICKET #4417 — Department website is down

**Raised by:** Head, ACMU Laboratory · **Priority:** High · **Host:** this machine

> "Since this morning http://acmu.isi.local/ shows *site can't be reached* from
> every machine in the department. It worked on Friday. One of the students was
> helping with the server last week. We need an admissions notice up this evening."

## 1. What exactly is the problem

The departmental web server is not serving the ACMU Laboratory site. The
service is not running, and it does not come back on its own.

## 2. How to reproduce it

```bash
curl -I -H 'Host: acmu.isi.local' http://127.0.0.1/
```

You get `Connection refused` — nothing is listening on port 80.

```bash
systemctl status nginx
```

Shows the service inactive.

## 3. What to fix

1. `curl -H 'Host: acmu.isi.local' http://127.0.0.1/` returns the department
   page. It contains the marker `ACMU-DEPT-PAGE`.
2. `curl -o /dev/null -w '%{http_code}' -H 'Host: acmu.isi.local' http://127.0.0.1/reports/`
   returns `200`.
3. The site comes back **automatically after a reboot**.

## Constraints — these are marked

- Do not change the contents of any page under `/srv/www/acmu`.
- Keep the permissions sane. This is a public web server, not a scratch box;
  making files world-writable or running the web server as root **loses marks**,
  even though either makes the page load.

## Notes

- There is more than one thing wrong. Fixing the first will expose the second.
- `nginx -t`, `journalctl -u nginx` and `/var/log/nginx/` will each tell you
  something different.
- Record every change in `~/FIXLOG.md`: symptom, cause, change, how you verified.
