# solar-overview

A planned Flutter app for Android and iOS showing solar production, household
consumption, battery state, and estimated appliance demand.

The installation has two solar sources: a SolarEdge inverter with its own panels
and a PowerFlex 2000Eco battery system with its own inverter and two panels.
Battery discharge will be shown separately from current solar generation.

## Current status

SolarEdge API access was verified on 2026-09-22. Production, daily energy, and
power history are available. Household consumption, grid flow, and battery power
were not present in the tested power-flow response. See the
[verification report](docs/solaredge-check.md).

The Flutter app has not been scaffolded yet. The first milestone is a SolarEdge
overview and history screen. Battery and smart-meter integrations follow once
their access methods are known.

## Tickets

1. [Verify SolarEdge API access](https://github.com/Owaiinnn/solar-overview/issues/1)
2. [Set up Flutter for Android and iOS](https://github.com/Owaiinnn/solar-overview/issues/2)
3. [Connect Flutter to SolarEdge](https://github.com/Owaiinnn/solar-overview/issues/3)
4. [Build the overview screen](https://github.com/Owaiinnn/solar-overview/issues/4)
5. [Add production history graphs](https://github.com/Owaiinnn/solar-overview/issues/5)
6. [Investigate and connect PowerFlex](https://github.com/Owaiinnn/solar-overview/issues/6)
7. [Connect household consumption](https://github.com/Owaiinnn/solar-overview/issues/7)
8. [Add the appliance planner](https://github.com/Owaiinnn/solar-overview/issues/8)
9. [Add weather and investigate solar forecasts](https://github.com/Owaiinnn/solar-overview/issues/9)

The initial ticket descriptions are in [docs/tickets](docs/tickets); GitHub issues
track ongoing status and discussion.

## Repeat the SolarEdge check

Requires Python 3.9 or newer and network access. No Python packages are required.

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
missing readings from zero. Platform-specific Flutter setup and checks will be
added in ticket 2.
