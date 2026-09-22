# S6 — VPN and firewall (18 marks)

| id | marks | what it checks |
|---|---|---|
| s6.iface | 1 | `wg0` brought up at all |
| s6.handshake | 4 | a real handshake — i.e. the peer key was corrected |
| s6.route | 2 | `AllowedIPs` fixed, so the subnet routes over the tunnel |
| s6.proxy | 5 | end-to-end: the service actually answers |
| s6.ufwon / s6.denyin | 1 + 1 | firewall still on, ingress still default-deny |
| s6.denyout | 3 | **egress still default-deny** — the policy constraint honoured |
| s6.ssh | 1 | did not lock the management port out |
| s6.penoff | −6 | `ufw disable` |
| s6.pengw | −5 | "fixed" the gateway instead of the client |

## Faults injected
1. `PublicKey` in `/etc/wireguard/wg0.conf` replaced with a valid-looking decoy key. The correct key is in `/opt/vpn-handover/central-it-email.txt` (and, for a candidate who thinks of it, in `ip netns exec vpngw wg show wg1 public-key`). **Symptom: total silence** — no error anywhere, `wg show` just never shows a handshake.
2. `AllowedIPs = 192.168.250.0/24`. Even with a good handshake, nothing routes to `10.100.0.2`. This one is invisible unless you know that WireGuard's `AllowedIPs` is simultaneously the routing table and the cryptokey-routing filter.
3. `ufw` rebuilt with default-deny egress and only 53 open — the tunnel's outbound UDP 51820 and the tunnel subnet are dropped. Correct fix is two `ufw allow out ...` rules, **not** `ufw default allow outgoing` and **not** `ufw disable`.
4. `wg-quick@wg0` stopped and disabled.

## What separates a strong candidate
- Reaches for `wg show` first and recognises "no handshake" as its own diagnostic class.
- Reads the handover note instead of guessing, and compares its key to the one in `wg0.conf`.
- Can explain `AllowedIPs` correctly. Most candidates, and most chatbot answers, describe it only as a routing entry; the good answer mentions that inbound packets from the peer are also *dropped* if their source is outside it.
- Opens two narrow egress rules rather than flipping the outgoing policy. This is the honesty test of the whole paper — the box "works" either way, and only the rubric knows the difference.
- Uses `tcpdump -ni veth-vpn udp port 51820` to show packets leaving (or not).

## Viva follow-ups
- "There was no error message anywhere. How did you decide where to look?"
- "Explain `AllowedIPs` to me as if I were a new student."
- "You could have run `ufw disable` and been done in ten seconds. Talk me through why that would have been the wrong answer, and what you would say if your supervisor asked you to do it anyway at 5pm on a Friday."
- "How would you monitor this tunnel so the library liaison never has to raise this ticket again?"
