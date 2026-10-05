## Purpose

Add reliable local grid import/export readings from the P1 smart-meter reader,
then establish household consumption only where the full energy balance is valid.

## Description

Device discovery and agent-run read-only checks completed on 2026-10-04. The
INDEVOLT app identifies the reader as P1-2WR and links it to the Home Energy Hub.
The owner enabled its separate local HTTP API. No Home Assistant or cloud relay
is required for the chosen home-network connection. The later home-network verification below records the device-reported meter
model and owner-confirmed installation coverage.

The Mac successfully read `GET /rpc/P1.JsonData` and `GET /rpc/P1.GetData` on port
8080 at the reader's own local address. The battery's `Indevolt.GetData` path
returned 404 on the reader: implement the P1 interface, not the battery client.
Reference: [IGEN/SOLARMAN OpenData](https://docs.solarman.ai/docs/api/opendata/).
The address and identifiers stay in local/device settings, not issues or git.

Agent-verified data and limitations:

- Live JSON uses snake_case fields rather than the reference's descriptive keys.
  `total_act_power` is import, `total_act_ret_power` export, and `target_power`
  is signed net power. In a paired sample, JSON export 520 and net -520 matched
  raw `1-0:2.7.0` of 0.520 kW and raw import of 0.000 kW. Thus the tested firmware's
  JSON power values are W, although the reference's example power fields use kW.
  Do not apply the reference's scale blindly to this response schema.
- The owner's app screenshot independently labels negative power as Feed-in.
  The paired raw/JSON export sample establishes direction and scale; import-side
  and changing-load verification still need completion.
- Raw `1-0:1.8.1`/`1.8.2` are tariff import counters; `2.8.1`/`2.8.2` are tariff
  export counters, explicitly in kWh. JSON `total_act_energy_LT/NT` and
  `total_act_ret_energy_LT/NT` matched rounded raw values in the sample.
  These are cumulative counters, not today's energy. The JSON aggregate export
  differed slightly from the sum of raw tariff counters, so choose explicit
  provenance/precision and verify consistency before displaying daily totals.
- `P1.GetData` includes meter timestamp `0-0:1.0.0` with the summer/winter suffix.
  The JSON sample had no measurement timestamp. Prefer timestamped raw readings
  or demonstrate safe association; do not relabel fetch time as measurement time.
  Validate timezone/DST, malformed telegrams and stale/repeated timestamps.
- Per-phase power, voltage and current are available. Phase and total fields may
  update at different times; do not enforce exact instantaneous equality without
  checking sampling. A returned gas zero is not evidence of a connected gas meter;
  gas monitoring is outside this scope.

Direct P1 readings measure grid exchange, not total household consumption. There
are only two solar sources (existing SolarEdge and SolaX) and the separate battery
in #6. Confirm they are all behind this meter. If household use is derived, first
verify the common AC boundary and use solar AC production + net grid import +
battery AC discharge, with charging/export represented by the opposite signs.
Do not mix battery-pack DC power with AC measurements or count bypass/solar twice.
The battery `5000` value of zero and SolaX `loadConsumption` are not established
household measurements. Prior SolaX investigation remains in `docs/solax-check.md`.

Cloud solar measurements and local meter/battery measurements have different
cadences. Define and test a defensible time-alignment policy for derived household
use; the existing 30-minute solar freshness and five-minute combined-solar skew
are not automatically sufficient for a live household balance. Show independent
grid readings even when derived consumption cannot be established. Do not clamp
an inconsistent balance to zero or provide surplus advice from incompatible data.

Implementation: independent local connection settings, secure persistence,
bounded foreground refresh/backoff, timestamped cache and off-network handling.
Away from home, show last saved readings with age; preserve both cloud sources.
Dependencies: the existing Flutter source structure; derived household flow also
depends on #6. #35 owns Home visualization, #36 owns local history, and #8
owns appliance headroom. No controls, cloud service, sample mode or gas feature.

Initial implementation handoff (2026-10-05): the owner was away from home. The app
implementation is on `feat/7-local-p1`, based on current main independently of
the open battery PR #39. No real P1 connection was attempted during the initial
implementation; subsequent live checks and the follow-up handoff are below.

- Added a read-only raw `P1.GetData` client with explicit OBIS units, precise
  integer-Wh tariff counters, meter identity and Dutch DSMR S/W timestamps.
  Missing values remain unavailable. Complete framed telegrams validate CRC;
  headerless vendor output cannot validate the original checksum. The separate
  untimestamped JSON endpoint is not used or mixed into raw readings.
- Added independent secure connection/cache storage, Settings test/save/replace/
  remove, Details import/export/zero states, cumulative tariffs and optional phase
  voltage/current. Failed replacements retain the old connection. Reader identity
  changes require explicit replacement; counter decreases produce a warning.
- Foreground refresh uses a provisional 30-second cadence, 90-second measurement/
  receipt freshness and 1/2/4/5-minute persisted failure backoff. Duplicate source
  timestamps cannot extend freshness. Old, inconsistent same-time and excessively
  future readings are rejected. Backgrounding stops polling; cache and waits
  survive controller restoration. These are app policies, not verified meter cadence.
- Household use remains unavailable: meter coverage, battery AC/bypass boundaries
  and cross-source time alignment are not established. No daily meter energy,
  household balance or surplus advice is derived. Home animation remains #35.
- Agent-run checks: Flutter 3.47.5 dependency resolution, formatting (49 files),
  analysis and all 166 unit/widget tests passed. Coverage includes timestamp/DST,
  units/signs/CRC, missing/invalid fields, stale/repeated readings, reset/identity
  handling, cache/backoff, replacement/removal, storage failures, backgrounding,
  large text and unchanged solar totals/waits. Android debug APK build passed;
  iOS plist syntax check passed, but this is not native iOS verification.
- API 36 emulator native test passed with an on-device synthetic HTTP server and
  isolated secure-storage keys: setup, controller/store recreation, persisted wait,
  import/export/zero, failure/recovery, 302/401 handling, replacement/removal and
  SolarEdge/SolaX storage isolation. Synthetic state screenshots were inspected.
  This does not prove real meter access, real off-network recovery or OS process
  persistence for a live P1 connection.
- Restored the normal app with `adb install -r`. All pre-existing preference
  entries were compared privately and preserved unchanged. Direct ADB walkthrough
  checked normal P1 Settings layout, empty-address validation, Details empty state
  and its connection navigation while existing solar connections remained intact.
  No source screenshots, raw responses, private addresses or credentials are committed.

Home-network verification (2026-10-05, after the owner returned):

- Owner confirmed that SolarEdge, SolaX and the battery are all behind this
  electricity meter. This establishes owner-reported coverage, not the battery's
  AC/bypass wiring or the timing needed for household calculations.
- Agent read the real P1 reader from the Mac and connected the Android API 36
  emulator through normal Settings. No reader settings or battery controls were
  changed. The real brace-wrapped, CRLF-framed telegram passed the production
  parser's checksum, units, identity and timestamp validation.
- Device reports P1-2WR, firmware `V1.4.0C_R021.102_MP12WR_D0000078`, DSMR
  version `50`, and meter header/model `ISK5\2M550T-1011`. All three phase voltage
  and current fields are present. These are device-reported values, not a physical
  inspection of the meter label or wiring.
- Paired raw/JSON readings agreed on 34 W import and, later, 1,770 W export
  (JSON signed net -1,770 W). The owner reported “from grid” 47 W; an agent sample
  during that exchange also read 47 W import. This supports direction and scale,
  but is not a clock-synchronized app comparison across battery operating modes.
- Four samples spaced ten seconds apart had advancing timestamps with subsecond
  receipt age and imports of 33, 47, 46 and 48 W. The S suffix correctly converted
  current Amsterdam summer time to UTC. Sampling demonstrated updates within
  ten seconds; the exact device cadence and a real DST transition remain untested.
- Normal Android UI showed live import and export, original local/UTC meter times,
  separate receipt time, cumulative tariff counters and all three phase readings.
  Automatic foreground updates were observed. A full app force-stop/relaunch
  restored the connection and resumed live readings without re-entry.
- With emulator Wi-Fi and mobile data disabled, the original export reading and
  timestamp remained saved. A second full app restart retained the saved reading
  and retry wait (87 seconds remaining), without claiming current exchange.
  Restored both network settings to their original enabled state. After the
  persisted retry gate expired, P1 recovered automatically to a new timestamp and
  recent export reading without reconnecting or bypassing the wait. This checks
  loss/return of connectivity on the emulator, not roaming on a physical phone.
- Existing solar connections remained usable, with separate refresh waits. A
  private preference comparison found all prior keys retained and the SolarEdge
  connection entry unchanged; the SolaX record refreshed normally. No solar
  replacement/removal was performed. Android debug build passed again; only
  documentation changed after these live checks. Earlier 166 unit/widget tests,
  native synthetic tests and PR CI remain passing. Private responses, screenshots,
  UI dumps and preference comparisons remain ignored and uncommitted.

Implementation handoff for PR #41: the local P1 integration is delivered and
verified as described above. The owner authorized merging the implementation on
2026-10-05. Remaining scope is preserved in linked follow-up issues before closing
this implementation ticket:

- [#42 — P1 device verification](https://github.com/Owaiinnn/solar-overview/issues/42)
  owns physical meter/phase checks, exact cadence and real DST behavior, independent
  comparisons through battery modes, tariff precision and physical Android/native iOS.
- [#43 — Household consumption](https://github.com/Owaiinnn/solar-overview/issues/43)
  owns battery AC/bypass boundaries, defensible timestamp alignment and conditional
  household calculations, including independent validation and unavailable states.

Unchecked items below remain uncompleted and are explicitly transferred to those
follow-ups; closing #7 does not claim they passed. The local ticket stays in
`docs/tickets/` as implementation and verification history. Protocol details,
source references and test commands are in [P1 notes](../p1-check.md).

## Todo

- [x] Identify the P1-2WR reader and its link to the INDEVOLT Home Energy Hub from owner-provided screens.
- [x] Obtain timestamped raw meter data and JSON readings through the enabled local HTTP API on the Mac.
- [x] Verify export sign and JSON power scaling against the raw telegram; identify tariff energy counters as cumulative kWh.
- [x] Record device-reported reader firmware, meter model/header and three-phase fields; obtain owner confirmation that both solar systems and the battery are behind this meter.
- [ ] Deferred to #42: verify physical meter/phase configuration, exact update cadence and real timestamp DST behavior; current summer-time conversion has been checked.
- [x] Implement the P1 client/parser with explicit firmware/schema mapping, raw units, timestamp validation, counter precision/provenance and malformed/missing-data handling.
- [x] Add independent mobile Settings test/save/replace/remove, secure persistence, cached readings, bounded foreground refresh/backoff and changed-address/off-network recovery without affecting existing connections.
- [x] Show net grid import/export, measurement time, cumulative tariff counters and optional phase detail in Details; distinguish grid exchange from household use and daily energy.
- [ ] Deferred to #42: compare live import and export with the meter/app, including battery charge/discharge; resolve aggregate-versus-tariff differences and guard meter resets/replacement.
- [ ] Deferred to #43: document battery AC/bypass boundaries and a timestamp-aligned household calculation with explicit availability/loss assumptions, using the owner-confirmed shared meter coverage.
- [ ] Deferred to #43: show household consumption only when required inputs are compatible and recent; keep missing/stale inputs unavailable and suppress unsupported surplus advice.
- [x] Test signs/scaling, raw timestamps/DST, missing versus zero, stale/repeated data, counter resets, inconsistent balances, cache and source isolation using synthetic fixtures.
- [x] Verify real-meter setup and saved readings after full process restart on the Android emulator; distinguish agent checks from owner-reported comparison/coverage.
- [x] Verify automatic recovery after emulator connectivity loss, persisted retry waits and preservation of existing solar connections.
- [ ] Deferred to #42: verify live setup, process restart and leaving/returning home on a physical Android phone.
- [x] Run required Flutter checks and emulator visual verification; preserve uncompleted physical Android/native iOS checks in #42 before closing.
