## Purpose

Complete the live provider comparisons deferred from the multi-source Overview
implementation in #4 / PR #27 without losing them when the implementation closes.

## Description

The owner authorized merging the Overview and redesign-planning PRs on 2026-10-01.
This follow-up preserves the remaining Overview acceptance work; it does not
claim that the comparisons have passed. The Home/Details redesign in #28 is now merged and retains these source and
calculation semantics. Battery/grid visualization in #35 must retain them too.

Agent-run verification for #4 passed 116 unit/widget tests, formatting, static
analysis, Android debug build, and live Android emulator checks of both existing
sources, combined output, SolaX MPPT/temperature details, navigation and cached
readings/refresh waits after force-stop/reopen. Small and iPhone-sized Flutter
viewports were checked with larger text. These checks do not establish agreement
with each provider's app or a native iOS build. No owner-run provider comparisons
have been reported.

Compare measurement timestamps and the same electrical boundaries, not merely
numbers fetched at the same wall-clock time. SolarEdge and SolaX have separate
panels/inverters confirmed by the owner; only their solar AC outputs are added.
Combined output requires both readings under 30 minutes old and at most five
minutes apart. A single eligible source is a named partial subtotal. Missing
readings are unavailable, not zero, and battery discharge is separate.

SolaX's device daily/lifetime AC counters are explicitly qualified and are not
silently replaced by plant/PV counters. Coordinate the end-of-day discrepancy
investigation with #25 rather than duplicating it here. Physical-device/native
iOS storage checks remain in #19/#25; record any Overview-specific layout findings
there or here as appropriate. Enter credentials only in mobile Settings and keep
private screenshots, account identifiers, credentials and raw responses out of
issues and git.

Backlog review (2026-10-04): no matching-time SolarEdge/SolaX provider comparison
was completed during the battery/P1 discovery. The INDEVOLT inverter card is a
view of the same SolarEdge source, not independent third-source production.
This ticket remains open; local-source validation belongs to #6/#7.

## Todo

- [ ] Compare SolarEdge power, today's energy and source time with the SolarEdge app/portal using matching measurement times; record any lag or mismatch without private identifiers.
- [ ] Compare SolaX AC output, status, source time, both DC MPPT channels and temperature with the SolaX app/portal; distinguish device AC counters from plant daily/lifetime totals and link energy-counter findings to #25.
- [ ] Compare combined power with the sum of eligible provider AC readings before display rounding; verify no DC input or battery discharge is included.
- [ ] Observe a live stale/offline or otherwise ineligible source and confirm its cached/error presentation and named partial subtotal; verify timestamps more than five minutes apart withhold a combined total. Preserve connections and provider cooldowns.
- [ ] Record agent-run versus owner-run comparisons separately and link any outstanding physical-device/native iOS work to #19/#25.

