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
this is an extension of that baseline, not a new screen from scratch. SolaX
connection/settings subsequently shipped in #21. Its read-only API check found
two MPPT inputs, timestamped AC output
and energy history, with stale readings and differing plant/device energy fields.
See `docs/solax-check.md` and #21 for mapping decisions that precede display work.

The app has no sample mode; use synthetic fixtures only in tests. Android first;
retain iOS layouts and record native iOS checks that remain deferred.

Implementation progress — 2026-10-01:

- Owner-requested layout adjustment: combined/partial power is the first card,
  above SolarEdge and SolaX. Agent verified the new order on Android; all 116
  tests, formatting and static analysis passed after updating existing scroll checks.

- The owner confirmed that SolarEdge and SolaX each have their own panels and
  inverter, with separate solar-only outputs. The house battery is its own later
  integration. This establishes the installation boundary used for AC combination;
  reconsider it if the selected systems or electrical topology change.
- Separate source cards now show power, explicitly sourced daily energy, status,
  measurement time, loading, saved/stale/unavailable states, errors and refresh.
  SolaX details show DC W/V/A for both MPPT channels, temperature and lifetime AC
  energy. Neither DC input nor battery discharge is added to solar AC output.
- Combined power requires readings younger than 30 minutes and at most five
  minutes apart, without source errors/storage failure/revoked access. A single
  eligible source is explicitly named as a partial subtotal. Missing data stays
  unavailable; a reported zero remains zero. Recent saved readings can qualify.
- Daily SolaX energy remains the explicitly qualified `dailyACOutput` device
  counter; `totalACOutput` provides lifetime AC energy. Plant/PV counters are never
  substituted. A verified daily headline and end-of-day discrepancy remain #25.
- Battery, household consumption and appliance headroom remain unavailable.
  Both source initializations and refreshes can proceed independently, including
  navigation while a source is loading. There is no sample mode or new polling.
- Agent-run checks: 116 unit/widget tests, static analysis, formatting and Android
  debug build passed. New tests cover zero/missing/stale/unknown/future readings,
  five-minute timestamp boundaries, partial totals, source failure isolation,
  cold saved snapshots, midnight, lifecycle freshness and no background polling.
  Layout tests passed at 360×640 and 390×844 with 1.5× text; the latter is an
  iPhone-sized Flutter viewport, not a native iOS build.
- Agent-run Android API 36 walkthrough used the existing live connections:
  both current readings, the combined total, independent disabled refresh waits,
  SolaX source-details expansion, both MPPT channels, temperature and lifetime
  energy rendered successfully. A force-stop/reopen restored both saved readings
  and their remaining refresh waits. Settings navigation retained both connections.
  Private screenshots and UI dumps stay outside git.
- No owner-run checks of this new screen or side-by-side provider-app comparisons
  are claimed. Native iOS/physical phone checks remain deferred; #19/#25 retain
  their existing device and energy-counter verification scope. This ticket stays
  open pending its PR and remaining acceptance checks.

## Todo

- [x] Show SolarEdge current production, today's energy, and last update in the existing overview.
- [x] Add SolaX AC production, today's energy with an explicitly selected source, connection/status and last measurement time without regressing SolarEdge.
- [x] Show the two SolaX MPPT inputs in source details, with voltage/current/power and inverter temperature where available; distinguish DC inputs from AC output.
- [x] Distinguish fresh source readings, cached/stale readings, missing data, loading and errors independently for each source; keep sample mode absent.
- [x] Replace the old PowerFlex-solar wording with separate SolarEdge, SolaX, PowerFlex battery and household-meter states in Overview and Settings.
- [x] Show battery and household consumption as unavailable until their separate integrations exist; do not interpret SolaX summary counters as these measurements.
- [x] Combine SolarEdge and SolaX only after confirming compatible AC measurement boundaries and freshness; expose partial totals clearly and never count both MPPT input and inverter output.
- [x] Do not label SolarEdge alone as combined production or calculate household surplus without all required flow measurements, including battery flows when relevant.
- [x] Keep source-specific daily/lifetime energy provenance explicit; never silently substitute differing plant and device totals.
- [x] Explain W/kW versus Wh/kWh with concise labels.
- [ ] Verify independent connection/failure states, stale timestamps and partial-source totals with synthetic tests and live comparisons against each provider's app.
- [x] Verify the layout on Android and iOS screen sizes, including larger text.
