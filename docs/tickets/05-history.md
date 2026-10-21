## Purpose

Help the owner understand production patterns and compare daily energy generation.

## Description

Let the owner inspect SolarEdge and SolaX production during a day and compare
daily energy totals, with each source clearly identified. This remains one history
feature; do not create a duplicate SolaX charts ticket.

Depends on: SolarEdge integration (#3); SolaX portions depend on #21. Build on the
existing History navigation/placeholder. SolarEdge history can be delivered before
SolaX is connected; keep source-specific availability visible.

Agent-run SolaX checks on 2026-09-28 returned daily entries for the current month
and 11 readings from a one-hour query at five-minute intervals. Fields included
AC output, two MPPT inputs, timestamps and energy. This verifies query access,
not full retention or complete time-series coverage. `inverterACOutputEnergy` was
populated while monthly `pvGeneration` was zero; plant/device energy totals also
differed. Verify field semantics, units and date boundaries before charting.
See `docs/solax-check.md`. Local battery/grid history and its collection policy
are tracked separately in #36, using the same History screen. #6/#7 establish
live device access; they do not imply that historical backfill is available.

Implementation (2026-10-19): History now has site-day selection, independent
SolarEdge/SolaX loads, separate AC curves and source totals, monthly daily
comparisons, optional SolaX DC input graphs, accessible reading lists and graph
inspection. Normalized snapshots persist securely with a 35-source/day bound.
History shares the existing per-source request lock, persisted 15-minute wait,
24-hour rate-limit backoff and SolaX token owner with live refresh. Date/source
navigation never fetches automatically. Connection/timezone changes hide
unrelated cached history; failed loads or cache writes retain prior snapshots.
Cache read failures offer retry or explicitly confirmed cache clearing, preserving
connections and quota waits. See `docs/production-history.md` for provenance and behavior.

The signed-in official SolaX reference was read on 2026-10-19 after the owner
signed in. It establishes five-minute history, maximum 12-hour UTC query windows,
a one-year history window and monthly plant AC statistics in kWh. Historical
energy uses `plantEnergyStatDataList[].inverterACOutputEnergy`; realtime device
counters, plant lifetime totals, zero `pvGeneration`, and DC inputs are never
substituted or summed. This resolves the field selection for historical totals;
the cause of the live counter reset/lifetime discrepancies remains open in #25.
SolaX power covers the selected inverter; its daily statistics cover the plant.
Daily energy totals remain separate. The owner's October 21 follow-up adds a
combined AC power curve as described below. Sources with different timezones
receive separate graphs.

Agent-run verification on 2026-10-19: Flutter 3.47.5 dependency resolution,
formatting, static analysis and all 302 unit/widget tests passed; the four Python
script tests passed. Synthetic tests cover units, missing/zero/negative readings,
23/25-hour DST dates, ambiguous SolarEdge times, SolaX query windows/retention,
cache restoration/revisions/failures, navigation during requests, quota gates,
revoked tokens and source/account isolation. Interaction/layout checks passed at
360×640 with 1.8× text. Android API 36 native secure-cache restoration, corrupt-cache
detection and the focused AC/DC screen walkthrough passed with isolated synthetic
records. Screenshots remain in ignored build output; no fixture mode or credentials
were added to the normal app. The normal Android target was restored; its History
navigation displayed the saved SolarEdge connection and persistent request wait.
The existing SolaX reconnect requirement now disables history loading with a
direct Settings action, without consuming another quota slot.

Graph visibility follow-up (2026-10-19): the chart area and source load controls
now appear immediately below the date selector, before the source summary cards.
An uncached day shows an explicit chart empty/loading/cooldown state rather than
hiding the chart entirely. Source and date changes still make no automatic API
requests and existing provider waits are preserved. Follow-up verification passed:
303 unit/widget tests, analyzer/format checks, and the Android cache/graph
walkthrough. The revised normal app was installed and its top chart waiting
state was inspected with the real saved connections.

Live Android graph verification (2026-10-21): loaded real SolarEdge power for
2026-10-19 and the associated monthly daily energy through the normal History
control after its saved request wait expired. The curve, daily energy, sample
coverage (45/96 buckets) and tap-to-inspect reading were rendered successfully;
missing intervals remained gaps. No saved connection or provider wait was reset.
A resume/date-rollover bug discovered during this check is fixed: an explicit
history load now keeps the displayed calendar date selected while it completes.
The new regression and all 304 unit/widget tests passed, along with analysis and
format checks. This is live API/UI verification, not comparison with either
provider's monitoring portal. SolaX required reconnection during that graph check.

Owner-authorized SolaX reconnection (2026-10-21): renewed authorization using the
emulator's existing secure credentials through the normal controller workflow.
The same account, plant and supported inverter were retained; a usable token,
source measurement time and live AC reading were persisted and read back from
secure storage. No other connection was replaced. The existing 15-minute request
wait was preserved, so a live SolaX history request remains pending after that
wait. The temporary native reconnection target was removed and the normal app
restored; no credentials or one-off reconnection code were committed.

Phone refresh investigation (2026-10-21): the owner refreshed History for October
20. Agent inspection found a valid SolaX cached power curve (123/288 available
samples) and daily energy, but SolarEdge's power-history load had failed and no
power snapshot for that date was saved. Its previously cached monthly energy
remained available. Both connections were retained; Home showed stale readings
because History refreshes do not update live power. The original generic HTTP
failure did not retain a status code, so its exact provider cause is unknown.

Per-source missing/loading/failure notices now appear beside a partially available
chart. Failed reloads explicitly retain the previous saved curve. Future SolarEdge
HTTP failures include only the status number and whether power history or daily
energy failed; keys, URLs and provider response bodies stay redacted. All 306
unit/widget tests, formatting and analysis passed. The Android walkthrough also
verified the partial-source failure banner with isolated synthetic records. The
normal app was restored; the live SolarEdge retry respects its persisted wait.

Live retry result (2026-10-21): after the persisted wait expired, the agent made
one normal in-app retry for October 20. SolarEdge's power-history request returned
HTTP 503 (Service Unavailable); no new SolarEdge curve could be saved for that
date. The SolaX curve stayed visible alongside the explicit failure banner. Both
connections and earlier cached history were retained, and the renewed request
wait was respected. The previous generic error's status cannot be reconstructed;
503 is the confirmed result of this retry, not an assumed cause for every prior
failure. No further request was made after this result.

Combined graph follow-up (2026-10-21): the owner requested one daily graph with
three lines: combined AC production, SolarEdge and SolaX. The combined line sums
the two source readings at matching normalized 15-minute UTC timestamps, with
gaps wherever either reading is unavailable. SolaX keeps its five-minute curve;
no interpolation, forward filling or interval averaging creates combined data.
Only matching calendar dates/timezones and supported five-/fifteen-minute
cadences combine. Duplicate, negative, nonfinite and overflowing samples stay
gaps; reported zeros remain zero. The legend identifies all three lines, with
the combined line thicker and blue, and inspection includes each sample's time.
Filtering or unloading either source removes the combined curve and explains
its requirements. Daily energy, DC inputs and batteries remain separate; this
change makes no additional provider requests and does not change saved waits.

Agent-run combined-graph verification: dependency resolution, formatting, analysis
and all 314 unit/widget tests passed. Tests cover exact sample alignment, missing
and invalid data, true zero, duplicates, overflow, incompatible dates/zones and
23/25-hour DST days. The Android API 36 walkthrough passed with isolated synthetic
cache records; visual inspection confirmed three distinct curves and point
inspection showing 447 W SolarEdge + 179 W SolaX = 626 W combined. Missing-source
and DC separation checks also passed. Captures stay in ignored build output.
The normal app target is restored with real connections and history preserved;
the earlier real October 20 SolarEdge HTTP 503 result still limits that day's
combined data. No new provider retry was made for this graph change. Monitoring
portal comparison and native iOS verification remain outstanding as below.

Real combined-day walkthrough (2026-10-21): the owner could not find a saved day
containing both providers. October 19 had SolarEdge power saved, while October
20 had SolaX power. After the existing SolaX request wait expired, one normal
in-app load saved October 19 SolaX history. The normal Android app now shows all
three real curves for October 19. Point inspection at 13:00 CEST displayed
SolarEdge 245 W + SolaX 97 W = combined 342 W. The app was left open on that
graph; connections, prior history and request waits were preserved. This is
live API/UI verification, not comparison with either monitoring portal.

Merge handoff (2026-10-21): after the real combined-day walkthrough, the owner
requested pushing and merging all open PRs. The History implementation is ready
for closure after merge. Historical sample/energy comparison with both monitoring
portals and native iOS History verification are explicitly deferred to open #65;
the SolaX daily/lifetime and zero-PV counter investigation remains in open #25.
The original acceptance checks below remain unchecked where those follow-ups
still own the work; closing the implementation does not claim they passed.

Remaining validation: selected historical readings and energy totals have not been
compared against both providers' monitoring portals. The old investigation token
was rejected during the initial investigation; the owner subsequently authorized
the saved emulator connection to be renewed, as recorded above. The agent did not mint a
separate investigation token or switch to another connection. Documentation/schema
review and synthetic/native tests are not live portal verification. Native iOS checks
remain deferred in #65. Close #5 after the implementation PR is merged and the
linked follow-ups are verified open, then archive this copy through a PR.

## Todo

- [x] Provide a selected-day power graph (W/kW) and daily energy totals (Wh/kWh).
- [x] Support SolarEdge and SolaX source selection/comparison, retaining useful history when only one source is connected.
- [x] Add SolaX intraday AC output and optional MPPT input series without adding DC input to AC output; use verified plant daily statistics for day/month comparisons.
- [ ] Document source/field provenance and resolve the SolaX daily/lifetime and zero-production-field discrepancies before using them in totals (unresolved counter investigation deferred to #25; historical field selection is documented above).
- [x] Select documented historical plant AC energy without substituting discrepant realtime/lifetime or zero PV fields; keep the unresolved live-counter cause in #25.
- [x] Query dates in the site's verified timezone and handle daylight-saving changes.
- [x] Preserve missing samples as gaps; do not treat missing readings as zero.
- [x] Cache history and use documented API date-range and request limits.
- [x] Include readable axis units, loading, empty, and failure states.
- [x] Label any combined series with its source coverage; combine only compatible units, measurement boundaries, intervals and dates, preserving gaps and partial coverage.
- [x] Test date/unit handling, missing buckets, API windows, caching and source isolation with synthetic fixtures.
- [ ] Verify selected historical readings and daily energy against both providers' monitoring portals; record dates, source fields and sanitized comparison results (deferred to #65).
- [x] Preserve remaining portal/native iOS verification in #65 and the unresolved SolaX counter investigation in #25 before closing the implementation.
- [x] Keep sample mode absent; verify Android first and record any deferred native iOS checks.
