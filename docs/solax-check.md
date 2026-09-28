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
