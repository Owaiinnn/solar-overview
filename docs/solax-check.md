# SolaX read-only API check

Agent-run verification on 2026-09-28 succeeded against the owner-confirmed EU
Developer API, `https://openapi-eu.solaxcloud.com`. This establishes access to the
panels and inverter; it is not a completed Flutter integration. The owner confirmed
that battery integration will come separately later.

## Verified capabilities

| Area | Result |
| --- | --- |
| Authentication | Client-credentials login succeeded; the token was reused successfully. Returned lifetime was approximately 30 days. |
| Discovery | One residential plant and one inverter; the tested inventory fit on one page. |
| Current readings | AC output, two MPPT input channels, voltage/current, frequency, temperature, energy counters, status and measurement timestamps were returned. |
| Intraday history | A one-hour query at five-minute intervals returned 11 timestamped samples. |
| Daily history | The monthly statistics request returned 28 dated daily entries with inverter AC output energy. |

Endpoints tested successfully:

- POST `/openapi/auth/oauth/token`
- GET `/openapi/v2/plant/page_plant_info`
- GET `/openapi/v2/device/page_device_info` for inverter, battery, meter and charger categories
- GET `/openapi/v2/plant/realtime_data`
- GET `/openapi/v2/device/realtime_data`
- GET `/openapi/v2/device/history_data`
- POST `/openapi/v2/plant/energy/get_stat_data` (read-only statistics)

No device controls, settings or permissions were changed. Credentials and the
reusable test token stayed in local Keychain storage; no secrets or raw responses
are included here. Initial screenshot transcription was corrected before the
successful authentication. Future credential entry should use copied text.

## Mapping and verification still required

- Successful HTTP responses do not prove fresh readings: the latest inverter
  measurement was over an hour old while the plant response time was recent.
  Base freshness on source measurement timestamps and verify status enums.
- Plant and device daily/lifetime energy fields differed. The latest inverter
  daily counters were zero despite nonzero plant daily energy and earlier device
  history. Verify end-of-day/reset behavior and choose explicit source fields.
- Monthly `inverterACOutputEnergy` was populated while `pvGeneration` was zero.
  Field names alone are insufficient to select the production series.
- DC input and AC output measure different electrical boundaries. Never add the
  MPPT input sum to inverter output, and verify compatibility with SolarEdge before
  combining the sources. Confirm units and hardware/topology against vendor docs.
- Preserve time-series gaps: a requested interval does not guarantee a complete
  set of samples. Resolve site timezone/DST and verify API date/window limits.
- No meter device or usable grid-power measurement was returned. Monthly
  `loadConsumption` equalled inverter output, so it is not established as measured
  household use. Zero grid/battery counters do not demonstrate zero physical flow.
- Battery and charger categories returned no devices. Additional device-type
  requests were rejected as unsupported; this does not establish physical absence.
- Longer history retention, sustained update cadence, rate-limit behavior, token
  renewal/revocation and token coexistence on multiple phones were not tested.

## References and follow-up

The [official Developer Portal reference](https://developer.solaxcloud.com/doc)
is the implementation reference. Its public document lookup returned errors during
the investigation. Request formats were cross-checked by inspecting, not executing,
the [public API client source](https://github.com/NoUsername10/Solax-Developer-API-for-Home-assistant/blob/main/custom_components/solax_developer_api/api.py).
The results above come from direct SolaX API calls, not that project's examples.
Verify vendor semantics and current limits before production implementation.

Connection/settings and normalized source state: [#21](https://github.com/Owaiinnn/solar-overview/issues/21).
Overview: [#4](https://github.com/Owaiinnn/solar-overview/issues/4).
History: [#5](https://github.com/Owaiinnn/solar-overview/issues/5).
Battery and household measurement remain separate in
[#6](https://github.com/Owaiinnn/solar-overview/issues/6) and
[#7](https://github.com/Owaiinnn/solar-overview/issues/7).

## Implementation verification — 2026-09-29

The official reference was successfully read through the signed-in Chrome portal
and its rendered page, despite the unauthenticated document lookup still failing.
The reference and [quick start](https://developer.solaxcloud.com/start) establish
client-credentials form authentication, lowercase `bearer` headers, approximately
30-day expiry, and renewal by obtaining another token. Information Management
and Monitoring Management are sufficient for the implemented endpoints; neither
an app code nor control permission is needed. Permissions also depend on the
subscribed service package and device authorization.

The signed-in [Package page](https://developer.solaxcloud.com/package) displayed
100 calls/minute and 1,000,000 calls/day for its default call resource. Treat these
as the observed package limits, not a promise for every account. The app uses a
15-minute device-local gate, bounded discovery and a 24-hour response-driven
backoff; it cannot coordinate quota across devices, reinstalls or clock changes.
Vendor Appendix 1 identifies 10402 as invalid token, 10403/10500/10505/10506 as
access denials, and 10405/10406 as exhausted quota/call-frequency limits. Unknown
provider messages remain redacted rather than guessed at.

A controlled live token check issued one new investigation token, saved it in the
existing local Keychain record, and tried old/new tokens on read-only inventory.
The previous token returned 10402 and the new token succeeded. **One application's
tokens do not coexist in this tested flow.** The supported configuration is a
separate developer application/client ID per phone, with token reuse until renewal.
Testing two physical phones with separate applications remains pending in #25.
Do not use a phone's application credentials in another API client or probe.

Verified mapping from the reference, “Query Device Real-time Data”, Appendices 4/6:

| Measurement | Explicit device field | Unit / interpretation |
| --- | --- | --- |
| Supported inverter | `deviceModel=28` | X1-Micro 2 in 1; other models are not enabled |
| AC output | `acPower1` | W for residential `businessType=1`; single-phase supported model |
| MPPT channels 1/2 | `mpptMap.MPPT{1,2}{Power,Voltage,Current}` | W, V, A; live uppercase prefix and documented lowercase prefix supported |
| Daily / lifetime AC energy | `dailyACOutput` / `totalACOutput` | kWh, normalized to Wh; never replaced by plant totals |
| Daily / lifetime PV yield | `dailyYield` / `totalYield` | Separate kWh provenance, not substituted for AC energy |
| AC electrical values | `acVoltage1`, `acCurrent1`, `acFrequency1` | V, A, Hz |
| Temperature | `inverterTemperature` | Celsius |
| Operating status | `deviceStatus` | Appendix 6; recognized states labeled, unknown codes remain unknown |
| Source measurement time | `dataTime`; fallback `plantLocalTime` | UTC; fallback plant-local with validated timezone/DST |

The live Dart client initially exposed two differences from the reference examples:
`dataTime` used ISO 8601 with `+00:00`, and the documented Amsterdam/Berlin timezone
label omitted spaces after commas. Both formats are now covered by synthetic
regression fixtures and the live client check passes. UTC source time takes
precedence over an ambiguous local DST hour. Unknown timezone labels are not
interpreted as fixed offsets or phone time.

The earlier energy discrepancy is not resolved by unit confirmation: AC output,
PV yield and plant summaries have different provenance, and the device's daily
AC counter was zero at idle on 2026-09-28 while plant statistics remained nonzero.
The implementation deliberately retains the reported device AC counter and its
source date, with a visible qualification. It does not synthesize energy from
power or silently fall back to a plant field. Before selecting #4/#5's headline
energy series, observe sunset/idle and midnight behavior and establish the cause;
this remains an unchecked item in follow-up #25.

Agent-run checks passed: live read-only Dart discovery/telemetry with an existing
token; 107 app unit/widget tests; format/static analysis; Android API 36 native
secure-storage lifecycle with isolated synthetic records. Native tests establish
persistence across controller/store instances, not a live mobile connection or OS
process-restart test. No raw responses, private IDs, credentials or screenshots
were committed. Live Android UI, physical phones and iOS remain pending in follow-up #25.
