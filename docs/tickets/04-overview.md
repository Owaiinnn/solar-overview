## Purpose

Give the owner a clear, trustworthy view of current solar production and available data sources.

## Description

Show SolarEdge and SolaX production separately, then combine compatible fresh AC
production readings without double counting. SolaX covers the panels and inverter;
PowerFlex battery access is later work in #6 and is not a prerequisite for showing
the solar sources. Household consumption and surplus require #7 and all necessary
flow measurements, not merely a successful solar API connection.

Depends on: the existing Flutter/SolarEdge foundation (#2/#3); SolaX portions depend
on #21. The existing SolarEdge view must remain usable while SolaX is disconnected.

Code review on 2026-09-28 found working SolarEdge power, today's energy, last-update,
refresh and stale/error presentation in `app/lib/src/app.dart`. Navigation exists;
this is an extension of that baseline, not a new screen from scratch. SolaX remains
unimplemented. Its read-only API check found two MPPT inputs, timestamped AC output
and energy history, with stale readings and differing plant/device energy fields.
See `docs/solax-check.md` and #21 for mapping decisions that precede display work.

The app has no sample mode; use synthetic fixtures only in tests. Android first;
retain iOS layouts and record native iOS checks that remain deferred.

## Todo

- [x] Show SolarEdge current production, today's energy, and last update in the existing overview.
- [ ] Add SolaX AC production, today's energy with an explicitly selected source, connection/status and last measurement time without regressing SolarEdge.
- [ ] Show the two SolaX MPPT inputs in source details, with voltage/current/power and inverter temperature where available; distinguish DC inputs from AC output.
- [ ] Distinguish fresh source readings, cached/stale readings, missing data, loading and errors independently for each source; keep sample mode absent.
- [ ] Replace the old PowerFlex-solar wording with separate SolarEdge, SolaX, PowerFlex battery and household-meter states in Overview and Settings.
- [ ] Show battery and household consumption as unavailable until their separate integrations exist; do not interpret SolaX summary counters as these measurements.
- [ ] Combine SolarEdge and SolaX only after confirming compatible AC measurement boundaries and freshness; expose partial totals clearly and never count both MPPT input and inverter output.
- [ ] Do not label SolarEdge alone as combined production or calculate household surplus without all required flow measurements, including battery flows when relevant.
- [ ] Keep source-specific daily/lifetime energy provenance explicit; never silently substitute differing plant and device totals.
- [ ] Explain W/kW versus Wh/kWh with concise labels.
- [ ] Verify independent connection/failure states, stale timestamps and partial-source totals with synthetic tests and live comparisons against each provider's app.
- [ ] Verify the layout on Android and iOS screen sizes, including larger text.
