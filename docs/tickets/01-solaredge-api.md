# Verify SolarEdge API access with a read-only smoke test

Confirm that the owner's supplied SolarEdge credentials can retrieve useful data
before starting the Flutter integration.

## Scope

Add a repeatable command-line check for the overview, production history, and
available power-flow fields. Use the Monitoring API matching the supplied key.
Do not control devices or change inverter settings.

## Acceptance criteria

- [x] Credentials can be entered without adding them to source control or command history.
- [x] Report whether authentication succeeds, current production in W, today's energy in Wh, and last-update time.
- [x] Check whether a dated power series is available for a graph; preserve missing readings as gaps.
- [x] Report whether consumption/grid fields exist without assuming they cover both solar systems.
- [x] Handle denied access, rate limits, network failures, and invalid responses without exposing the key.
- [x] Record the outcome and remaining uncertainties without copying credentials, site identifiers, or raw responses into the issue.

Reference: https://knowledge-center.solaredge.com/sites/kc/files/se_monitoring_api.pdf

First ticket; no dependency on Flutter or battery access.

## Verified outcome — 2026-09-22

The live check succeeded: approximately 177 W current production, 152 Wh energy
today, and 13 populated history samples. Last overview update: 10:35:16 in site
local time. PV was present in power flow; LOAD, GRID, and STORAGE were unavailable.
There is enough data for the first SolarEdge dashboard and history graph.

Added `scripts/check_solaredge.py` with hidden credential entry and no raw response
logging. Four offline checks passed for credential redaction, redirect blocking,
and missing-value/unit reporting. See `docs/solaredge-check.md` for limits of this
check. Actual refresh cadence, site timezone, and household measurement coverage
remain integration work.
