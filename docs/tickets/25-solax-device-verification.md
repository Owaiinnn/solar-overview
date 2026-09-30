## Purpose

Complete the live-device and energy-counter verification deferred from the SolaX
connection implementation in #21 and PR #24.

## Description

The owner requested merging PR #24 and completing #21 on 2026-09-30. These checks
are carried forward explicitly; closing the implementation ticket does not claim
that they passed. Overview/history presentation remains in #4/#5.

Agent checks on 2026-09-29 passed 107 app unit/widget tests, static analysis,
Android API 36 native secure-storage lifecycle with isolated synthetic records,
and real read-only EU discovery/telemetry using the new Dart client on the Mac.
Native tests cover persistence across controller/store instances, replacement,
removal, persistent cooldown and SolarEdge isolation. They do not establish a live
Android UI connection or persistence across OS process termination. No owner-run
SolaX mobile checks have been reported. Full Xcode/iOS remains unavailable.

A live token check established that issuing a new token invalidates the previous
token for the same SolaX developer application. Each phone must use a separate
application/client ID; do not share its credentials with scripts or other clients.
Enter real credentials only in mobile Settings. Do not publish credentials,
private identifiers, locations, screenshots or raw API responses.

Device `dailyACOutput`/`totalACOutput` are documented AC energy in kWh; PV yield
and plant counters have separate provenance. The app uses the device AC counters,
never silently falls back to plant fields, and qualifies the possible discrepancy.
The earlier probe found a zero daily device counter at sunset despite nonzero
plant statistics. Its cause and the appropriate headline series for #4/#5 remain
unverified. See `docs/solax-check.md` for the established mapping and observations.

## Todo

- [ ] In Android Settings, test/save a live EU SolaX connection, select the correct plant and X1-Micro 2 in 1, and verify power, status and source time.
- [ ] Fully terminate/reopen the Android process; confirm credentials/token/readings persist and the 15-minute wait remains without obtaining another token.
- [ ] After the wait, verify successful refresh, then offline cached readings and stale labeling after 30 minutes.
- [ ] Verify replacement/removal through Android Settings; confirm SolarEdge credentials, readings and refresh wait remain independent.
- [ ] Confirm two physical phones with distinct developer applications stay connected through token renewal; never share a client ID.
- [ ] Compare device AC energy, plant statistics and source timestamps before sunset, during idle/offline, and after site midnight; establish the cause of the daily-counter discrepancy.
- [ ] Choose #4/#5's daily-energy series explicitly, preserving gaps and measurement boundaries without substituting unavailable values with zero.
- [ ] Verify physical Android and deferred iOS secure storage, process restart, replacement/removal and source isolation when available.
- [ ] Record owner-run versus agent-run checks separately, with no credentials or private raw data.
