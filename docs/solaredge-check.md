# SolarEdge connectivity check — 2026-09-22

Result: successful read-only access using the supplied monitoring credentials.
No keys, site identifiers, screenshots, or raw API payloads are included here.

## Observations

| Reading | Returned value |
| --- | --- |
| Last overview update | 2026-09-22 10:35:16 (site local time) |
| Current production | 177.13785 W, approximately 0.177 kW |
| Today's energy | 152 Wh, or 0.152 kWh |
| Power history for September 22 | 13 numeric samples, 83 missing/non-numeric entries |
| Highest populated history sample | 136.27243 W |
| Power-flow fields | PV present; LOAD, GRID, and STORAGE unavailable |

The history request covered the complete calendar day, so empty entries can
include future intervals. History samples and the overview have different
sampling/update behavior; the history maximum is not a claim about the day's
instantaneous maximum.

The three GET requests used `/site/{siteId}/overview`, `/site/{siteId}/power`,
and `/site/{siteId}/currentPowerFlow` at `https://monitoringapi.solaredge.com`.
Endpoint reference: [SolarEdge Monitoring API](https://knowledge-center.solaredge.com/sites/kc/files/se_monitoring_api.pdf).

## Implications

- The first Flutter dashboard can display SolarEdge production, daily energy,
  and a graph without waiting for the other equipment.
- The tested response does not establish household consumption or PowerFlex
  panel/battery readings. The smart-meter and battery integrations are still needed.
- Do not infer combined solar production, household surplus, or appliance advice
  from SolarEdge production alone.
- Credentials were extracted locally from the supplied image in memory and sent
  only to SolarEdge for this check. They were not written into the repository.

## Still to verify during integration

- The site's timezone and actual cloud-data freshness/update frequency.
- Applicable request limits and a shared caching/refresh strategy.
- Whether the meter measures net grid exchange or household consumption and how
  the separate battery system affects those readings.
- Inverter model and any additional historical data needed by the app.

The script's four offline tests passed: network-error redaction, HTTP-error
redaction, redirect blocking, and unit/missing-value reporting.
