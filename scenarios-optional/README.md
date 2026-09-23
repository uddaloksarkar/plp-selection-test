# Inactive scenarios

These four are complete and working, but are **not part of the current paper**.
The examination was reduced to three scenarios (disk, permissions, SSH tunnel) so that
candidates have time to diagnose properly rather than skim six.

Nothing here is built, armed or scored — `bin/exam-ctl.sh` and
`bin/make-candidate-bundle.sh` only look in `scenarios/`.

| Scenario | Domain | Raw | Why it was held back |
|---|---|---|---|
| `s1-website` | Linux / service | 18 | Good, but overlaps with the permissions scenario on the docroot fault |
| `s4-dns` | Networking | 16 | Replaced by `s7-tunnel`: four layered resolver faults proved too hard for the level of the post |
| `s5-python` | Software | 16 | The `sys.path` shadowing fault is excellent, but needs more Python depth than the post requires |
| `s6-vpn` | Networking / security | 18 | The strongest ethics test in the set, but WireGuard is specialist knowledge for this role |

To put one back: move its directory into `scenarios/`, add it to the `ALL` array
in `bin/exam-ctl.sh`, adjust the ticket count check in `lib/steps/40-arm.sh`, and
re-run `./plp provision && ./plp arm`.
