# solar-overview

A planned Flutter app for Android and iOS showing solar production, household
consumption, battery state, and estimated appliance demand.

The solar sources are SolarEdge and SolaX panels/inverter. The PowerFlex 2000Eco
battery is a separate, later integration; its API and precise electrical topology
still need verification. Battery discharge stays separate from solar generation.

## Current status

SolarEdge API access was verified on 2026-09-22. Production, daily energy, and
power history are available. Household consumption, grid flow, and battery power
were not present in the tested power-flow response. See the
[verification report](docs/solaredge-check.md).

SolaX EU Developer API access was verified on 2026-09-28: inverter AC output, two
MPPT input channels, electrical details, timestamps and intraday/daily history are
available. Stale readings and differing plant/device energy fields need explicit
handling. See the [SolaX verification report](docs/solax-check.md).
The Flutter SolaX connection is planned in [#21](https://github.com/Owaiinnn/solar-overview/issues/21),
not implemented yet. Battery and household-meter APIs remain separate work.

The Flutter starter is in [app](app/README.md), with Android/iOS targets and
SolarEdge settings for testing and saving a connection on each phone. A basic
overview and navigation for Appliances, History, and Settings are included.
Android is the current development priority; iOS remains a target but native iOS
verification is deferred.

Verified as of 2026-09-23: the Android debug build and API 36 emulator launch,
plus a native storage integration test using synthetic data. The owner also
confirmed a live SolarEdge connection updates both screens, credentials persist
after closing/reopening the app, and removal works on the Android emulator.
Real Android phone testing is still pending. Full Xcode is not installed; iOS
build/storage checks remain pending. Android Studio, the Android SDK and CocoaPods
are installed on the development Mac.

Ticket #3 reliability work was merged in
[PR #18](https://github.com/Owaiinnn/solar-overview/pull/18):
secure saved readings, a persistent 15-minute refresh wait, 24-hour rate-limit
backoff, and site-timezone-aware stale readings and daily energy. Automated
failure-path checks and Android native-storage tests passed. Tickets #2 and #3
are closed following their implementation merges. Remaining live cache/timezone,
physical Android and deferred iOS verification is tracked separately in
[#19](https://github.com/Owaiinnn/solar-overview/issues/19); those checks have not
been reported as passed. Ticket #2's navigation is implemented and sample mode
was removed at the owner's request.

Ticket #4 extends the existing SolarEdge overview to the separate solar sources;
its SolaX portions depend on #21. Ticket #5 covers history for both solar sources.
Suggested next implementation: #21, then the remaining #4/#5 work. Battery (#6)
and smart-meter (#7) integrations follow separately and do not block solar-only
monitoring. Appliance headroom still requires all relevant flow measurements.

## Working one ticket per chat

Start a new chat with this repository selected as the workspace. `AGENTS.md`
contains durable project and workflow instructions, including closing linked
GitHub issues after merging and preserving deferred work in follow-up issues.
The selected GitHub issue and its local copy contain the task scope and progress. Update those notes at each
handoff instead of relying on previous conversations.

Example starting message:

> Work on ticket #21. Read AGENTS.md and the GitHub issue first. Inspect what
> already exists and implement only the remaining work on a new branch with
> small logical commits. Android first. Do not merge without asking.

For development commands, see [app/README.md](app/README.md). On the owner's Mac,
the ignored `LOCAL_LAUNCH.md` includes a one-command emulator launcher; local
helpers are not included in fresh clones.

## Tickets

1. [Verify SolarEdge API access](https://github.com/Owaiinnn/solar-overview/issues/1)
2. [Set up Flutter for Android and iOS](https://github.com/Owaiinnn/solar-overview/issues/2)
3. [Connect Flutter to SolarEdge](https://github.com/Owaiinnn/solar-overview/issues/3)
4. [Build the overview screen](https://github.com/Owaiinnn/solar-overview/issues/4)
5. [Add production history graphs](https://github.com/Owaiinnn/solar-overview/issues/5)
6. [Investigate and connect the PowerFlex battery later](https://github.com/Owaiinnn/solar-overview/issues/6)
7. [Connect household consumption](https://github.com/Owaiinnn/solar-overview/issues/7)
8. [Add the appliance planner](https://github.com/Owaiinnn/solar-overview/issues/8)
9. [Add weather and investigate solar forecasts](https://github.com/Owaiinnn/solar-overview/issues/9)
10. [Add animated energy icons with a green flow effect](https://github.com/Owaiinnn/solar-overview/issues/11)
11. [Replace the home-screen app icon with a house-outline logo](https://github.com/Owaiinnn/solar-overview/issues/15)
12. [Complete deferred live-data and device verification](https://github.com/Owaiinnn/solar-overview/issues/19)
13. [Connect Flutter to SolaX panels and inverter](https://github.com/Owaiinnn/solar-overview/issues/21)

Ticket copies are in [docs/tickets](docs/tickets); check GitHub issues for current
open/closed state and discussion. A local file's existence does not mean it is open.

All ticket bodies use exactly three sections: **Purpose**, **Description**, and
**Todo**. Keep local ticket copies and GitHub issues synchronized, put progress and
dependencies under Description, and use checkboxes under Todo. New issues can use
the repository's Task template.

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
