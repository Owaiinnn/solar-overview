## Purpose

Complete real-device and measurement validation for the local INDEVOLT battery integration while keeping unverified battery data out of household calculations.

## Description

Follow-up to implementation ticket #6 and PR #39, created for the owner's requested merge on 2026-10-06. The read-only client, independent secure cache, Settings/Details and bounded foreground refresh are implemented. Earlier agent-run checks verified Mac HTTP access, Android emulator native secure storage, synthetic native HTTP and battery setup/Details UI. These do not establish physical-device behavior or measurement semantics.

Preserve ticket #6's outstanding scope: prior-chat/device evidence, exact model, firmware/modules/capacity, charge/discharge/idle comparisons, pack DC versus AC/bypass boundaries, source timing/cadence and daily counter resets. Receipt age is not source measurement time; no verified usable-energy or household-balance claim is allowed. Household calculations belong to #43, Home graphics to #35 and history to #36.

Use home-network-only HTTP and preserve saved connections and cloud cooldowns. Enter addresses/credentials only through Settings; do not upload private screenshots, raw responses or identifiers. Use --no-uninstall for Flutter integration tests and --keep-app-running for flutter drive. Distinguish agent-run checks from owner-reported evidence. Native iOS checks may remain deferred without blocking Android work.

Evidence from 2026-10-06 (Europe/Amsterdam): the agent's read-only Mac probe at 15:37:50 returned SOC 100%, idle, pack DC 0 W, inverter AC 0 W, total AC 0 W, daily charged 7.15 kWh and discharged 1.11 kWh. Owner-supplied INDEVOLT screenshots, reported as approximately 15:40 and displaying 15:39, show 100%, Standby, battery 0 W and the same charge/discharge counters. These nearby observations support the idle mapping; they are not simultaneous samples or evidence for charging/discharging signs. The screenshots identify PowerFlex 2000Eco, Key Load bypass and no cluster. The system-config response identifies CMS-SF2000 with firmware V1.4.0E_R00D.0B2_M4801_0000003E. A badge of 2 and two nonempty module identifier slots are consistent, but module models and usable capacity remain unverified. Field 142 returned 6.05 kWh while the app displayed 6.04 kWh; do not equate either with verified usable capacity.

The same-day P1 probe returned a source timestamp about one second before receipt and grid export, but it was not synchronized with the screenshot's grid/solar/load values. This does not verify a household balance or sustained update cadence. A planned longer sampling run has no retained result and is not counted as completed. Full dated evidence and limitations are in docs/battery-check.md.

On 2026-10-07, new read-only probes could not reach either local device. The owner confirmed the Mac was on another network. This is a home-network access limitation, not evidence of a device or app defect. Yesterday's screenshots remain historical evidence and must not be compared with today's readings. Resume fresh device probes and mobile connection/restart/offline/recovery checks when home connectivity is available. No physical Android device was connected; Xcode was unavailable for native iOS checks. No battery control or network-setting changes were made during these probes.

Resumed home-network checks on 2026-10-07, 18:45–18:58 Europe/Amsterdam: both APIs returned HTTP 200. Battery data initially reported 42.6%, discharging, pack DC 726 W and inverter/total AC -661 W. Eight retained 30-second samples captured idle with pack DC 26 W and AC 0 W, then discharge with positive pack and negative AC power. The owner's 18:46 device-page screenshot shows 43%, Standby, zero AC output and 5.72/3.23 kWh counters; the nearby 18:46:39 API sample reports 42.5%, idle and 5.72/3.24 kWh. These are nearby observations, not synchronized validation. Charging, the reason for nonzero idle pack power, capacity and reset timing remain unresolved.

Live Android API 36 emulator checks passed: both devices saved through Settings, real Details readings, automatic foreground refresh, saved readings after network failure, increased retry backoff, secure persistence across full process restarts and automatic recovery after network restoration. A restart with pending waits retained the deadline (P1/battery 55/56 seconds at 18:56:45, then 30/32 seconds at 18:57:10); both sources recovered by 18:58:10. Solar connections and cooldowns remained intact. Emulator Wi-Fi/mobile data were restored to their initial enabled states. A private helper assertion interrupted the first sequence after force-stop; cleanup restored networking and the remaining checks were continued separately. No app code changed; this documentation-only update uses diff, ticket-format and link checks, not a rerun of app tests. These emulator results do not complete physical Android or native iOS verification.

An owner screenshot of the home overview at 18:59 conflicts with eight nearby Mac probe pairs: overview battery 43%/Standby/26 W and export 116 W, versus API battery 40.0–40.1%/discharging/693–694 W and P1 import 1,477–1,612 W with zero export. The overview resembles an earlier standby sample, so staleness is a hypothesis, not a verified cause. After the refresh/reopen request, the owner reported “40% now”, supporting agreement with recent local SOC and the stale-overview hypothesis for that field. No updated state/grid values or exact sample time were supplied; that comparison remains open. Do not change normalization or claim full independent agreement. Full evidence and limitations are in docs/battery-check.md; meter-specific observations belong to #42.

The owner requested another check: at 19:06:27 the battery API returned 36.8%, discharging, pack DC 2,451 W and inverter/total AC -2,240/-2,238 W, with P1 export 1,761 W. A 19:07:53 probe showed 35.9%, pack DC 2,422 W and export 1,878 W. The agent visually verified Solar Overview tracking the changed state (36%, discharging and about 2.4 kW pack power, plus 1.881 kW export from meter time 19:07:27). Later export does not validate the earlier mismatched vendor snapshot or household balance.

## Todo

- [x] Record commercial model and reported firmware from dated owner screenshots and agent-run device probes.
- [ ] Verify installed module models, usable versus rated capacity and field scaling using device evidence.
- [x] Compare idle SOC/state/power and charge/discharge counters with nearby owner-supplied app screenshots from 2026-10-06.
- [ ] Compare charging/discharging states and synchronized live readings against the INDEVOLT app, including sign conventions and inconsistent readings.
- [ ] Resolve the 2026-10-07 18:59 vendor-overview versus local-API discrepancy with a refreshed, time-aligned comparison.
- [ ] Verify pack DC versus inverter/total AC and bypass boundaries; record what remains unsuitable for household balance in #43.
- [ ] Establish source timestamp availability, update cadence and stale-device behavior; verify daily charge/discharge counter units, completeness and reset behavior.
- [ ] Verify physical Android live connection, saved readings after restart, off-network failure/backoff and recovery on returning home without resetting solar waits.
- [x] Verify real-device connection and Details, automatic refresh, saved readings, process restart, persisted retry waits and network recovery on the Android emulator while preserving solar connections/cooldowns.
- [ ] Verify iOS local-network permission/HTTP access, secure persistence, foreground/background refresh and Settings/Details on a simulator or device.
- [x] Record the 2026-10-06 evidence and current limitations in docs/battery-check.md and this ticket without private data.
- [ ] Record remaining verification results; update normalization only when supported by verified findings.
