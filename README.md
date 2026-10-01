# solar-overview

A Flutter app for Android and iOS with independent SolarEdge and SolaX solar
readings, source details, and combined production when fresh measurements align.
Household consumption, battery state, history and appliance planning are later work.
See [app/README.md](app/README.md) for behavior, verification and launch commands.

The solar sources are SolarEdge and SolaX panels/inverter. The PowerFlex 2000Eco
battery is a separate, later integration; its API and precise electrical topology
still need verification. Battery discharge stays separate from solar generation.


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
missing readings from zero. Flutter setup and checks are documented in
[app/README.md](app/README.md).
