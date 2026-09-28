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
See `docs/solax-check.md`. Battery history is deferred with #6.

## Todo

- [ ] Provide a selected-day power graph (W/kW) and daily energy totals (Wh/kWh).
- [ ] Support SolarEdge and SolaX source selection/comparison, retaining useful history when only one source is connected.
- [ ] Add SolaX intraday AC output and optional MPPT input series without adding DC input to AC output; use verified plant daily statistics for day/month comparisons.
- [ ] Document source/field provenance and resolve the SolaX daily/lifetime and zero-production-field discrepancies before using them in totals.
- [ ] Query dates in the site's verified timezone and handle daylight-saving changes.
- [ ] Preserve missing samples as gaps; do not treat missing readings as zero.
- [ ] Cache history and use documented API date-range and request limits.
- [ ] Include readable axis units, loading, empty, and failure states.
- [ ] Label any combined series with its source coverage; combine only compatible units, measurement boundaries, intervals and dates, preserving gaps and partial coverage.
- [ ] Verify selected readings against both providers' portals and test date/unit handling, missing buckets, API windows, caching and source isolation with synthetic fixtures.
- [ ] Keep sample mode absent; verify Android first and record any deferred native iOS checks.
