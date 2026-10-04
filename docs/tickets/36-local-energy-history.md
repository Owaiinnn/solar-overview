## Purpose

Let the owner review battery charge/discharge and grid import/export over time,
with honest coverage for devices available only on the home network.

## Description

Later follow-up to the local battery/meter integrations #6/#7, requested as part
of the device-integration backlog review on 2026-10-04. Reuse the History feature
and its date/source navigation from #5; #5 remains responsible for SolarEdge/SolaX
production history. This ticket adds local battery/grid series rather than a
second History screen. It does not block live readings or the Home animation in #35.

Current verification establishes battery telemetry/daily counters and P1 raw
meter timestamps/cumulative tariff counters. It does not establish historical
query/backfill endpoints, retention, battery midnight behavior or complete daily
coverage. First investigate supported read-only historical access. If unavailable,
record timestamped samples while the app is active at home and make gaps explicit.
The owner chose local access: do not add a cloud service, always-on gateway or
background collection requirement to fill those gaps.

Track battery SOC and charge/discharge power separately from grid import/export
and solar generation. Choose battery pack versus AC energy provenance explicitly.
Use verified P1 tariff counters/precision; JSON aggregate and tariff sums differed
slightly during discovery. An energy-counter difference across a gap may establish
interval energy if both endpoints are valid, but cannot reconstruct a missing
power curve or split energy across unobserved day boundaries. A midday first
sample cannot establish today's full import/export total. Handle counter resets,
rollover, device replacement, timezone/DST and battery daily-counter rollover.

Persist a bounded local history with a documented retention/storage policy and
per-device identity so replacement does not join unrelated counters. Show which
intervals are observed, missing or incomplete. Reuse integration refresh results
rather than introduce another polling loop. Never interpolate missing data into
apparently measured production/consumption or count battery output as new solar.

Dependencies: #6/#7 verified field semantics and normalized readings; #5 shared
History UI. Native/physical verification gaps must be recorded explicitly. No
appliance scheduling, gas history or cloud MQTT service in this scope.

## Todo

- [ ] Establish whether supported battery/P1 historical retrieval or backfill exists; document the result, cadence, retention and limits.
- [ ] Define a bounded local persistence/retention policy using existing foreground refreshes, with device identity and explicit gaps when away from home or the app is closed.
- [ ] Add battery SOC and charge/discharge series plus grid import/export to the shared History screen with explicit units and source provenance.
- [ ] Derive interval/daily energy only from valid compatible counters and observed date boundaries; label incomplete days instead of inventing midnight baselines.
- [ ] Handle timezone/DST, stale/duplicate timestamps, missing samples, counter precision/reset/rollover and device replacement without negative or double-counted energy.
- [ ] Keep solar production, battery energy and grid exchange separate; any household series must satisfy #7's calculation and alignment rules.
- [ ] Test counter/date/gap handling and persistence using synthetic fixtures and compare selected real intervals with meter/INDEVOLT readings.
- [ ] Verify History navigation, loading/empty/offline states and readable graphs on Android; record outstanding native iOS checks before closure.
