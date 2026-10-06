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

## Repeat the SolarEdge check

Run from the repository root. Requires Python 3.9 or newer and network access.
No Python packages are required.

```sh
python3 scripts/check_solaredge.py
```

Enter the site ID when prompted, then the API key at the hidden prompt. The check
makes up to three read-only requests to SolarEdge: overview, power history for
the overview reading's date, and current power flow. It stops on request errors,
does not follow redirects, and does not save credentials or raw responses.
Zero production is a valid reading; missing data stays unavailable.

For automated use, credentials may be injected as `SOLAREDGE_SITE_ID` and
`SOLAREDGE_API_KEY` environment variables, or as JSON through stdin using
`--credentials-stdin`. Do not put actual credentials into shell commands, issue
descriptions, source files, or mobile app build flags. This script does not
automatically load `.env` files.

This is a connectivity check, not a background collector. It does not verify
update frequency, full meter coverage, or whether the readings are fresh enough
for appliance advice.

## Check the script

```sh
python3 -m unittest discover -s scripts -p 'test_*.py' -v
```

These offline checks cover error redaction, redirect blocking, and distinguishing
missing readings from zero. Flutter setup and checks are documented in
[app/README.md](../app/README.md).

## Flutter request and storage safeguards

`app/lib/src/connection_controller.dart` reserves the 15-minute request gate
before network access, including connection tests and replacements. Failures and
process termination consume that slot. A rate-limit response extends the wait to
24 hours. The in-memory deadline survives a failed storage write; requests stop
until storage recovery persists it. Freshness notifications run on resume and
once a minute without polling the API.

The reading store atomically couples normalized readings and the request gate;
it never stores keys, URLs or raw responses. The credential store keeps site ID
and key in one entry so they cannot be mixed across saves. Replacement invalidates
the previous snapshot before writing new credentials, preventing a crash from
associating old readings with a new key. A failed credential write restores the
previous cache; a later snapshot-save failure does not undo valid credentials.
The reliability tests inject failure at the third write (reservation, invalidation,
snapshot) and at the second write of a rate-limited refresh (reservation, extended
gate). Removing a corrupt cache retains a conservative 24-hour pause because its
previous quota state is unknown.

The Flutter client requests overview before site details, sequentially, so rejected
credentials do not trigger another request and concurrent requests do not increase
provider load. Credential diagnostics are redacted. Network exceptions may contain
key-bearing URLs; neither client nor check script forwards exception strings or
raw responses to UI/logs. The script blocks redirects to prevent credential
forwarding and requests the overview reading's local calendar day without assuming
UTC.

`app/lib/src/site_time.dart` includes the full IANA database and its aliases,
including Europe/Amsterdam and UTC. It rejects overflowing dates/times that Dart
would otherwise normalize, as well as missing or repeated DST hours without an
unambiguous instant. The native credential/cache tests use separate synthetic
storage keys, never the owner's saved connection.
