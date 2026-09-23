# TICKET #4442 — VPN to the campus e-library is down

**Raised by:** Library liaison, ACMU Lab · **Priority:** Medium-High · **Host:** this machine

> "This host is the department's gateway to the campus e-library proxy over the
> WireGuard VPN. Since Monday's security hardening, nothing reaches the proxy.
> Central IT say their end is fine and they have not changed anything."

## 1. What exactly is the problem

The WireGuard tunnel `wg0` is not carrying traffic. A misconfigured WireGuard
tunnel fails **silently** — nothing is logged, and there is no error message
anywhere. Some faults are in the tunnel configuration and some are in the host
firewall.

## 2. How to reproduce it

```bash
curl --max-time 5 http://10.100.0.2:8080/      # times out
```

```bash
sudo wg show                                    # no "latest handshake" line at all
sudo systemctl status wg-quick@wg0
ip route get 10.100.0.2
sudo ufw status verbose
```

## 3. What to fix

1. The tunnel `wg0` is up and has a **recent handshake**.
2. `curl http://10.100.0.2:8080/` from this host returns the proxy page — it
   contains `LIBRARY-PROXY-OK`.
3. The tunnel comes back automatically after a reboot.

## Constraints — these are marked

- **The host firewall stays on, and the default policies stay deny-incoming and
  deny-outgoing.** Campus security policy requires it. `ufw disable` or
  `ufw default allow outgoing` makes the problem disappear and **loses marks**.
  Open only what is needed.
- Keep the existing rule that lets you reach this machine over ssh.
- **Do not touch the gateway end.** You do not administer it, and changes there
  will be noticed.

## Notes

- `/opt/vpn-handover/central-it-email.txt` holds the parameters Central IT issued
  for this host. Treat it as authoritative.
- `/etc/wireguard/wg0.conf` is the local configuration as it stands now.
- Be ready to say which of the faults you found were firewall faults and which
  were tunnel faults.
- Record every change in `~/FIXLOG.md`.
