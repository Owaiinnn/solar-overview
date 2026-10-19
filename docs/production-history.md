# Production history

History compares SolarEdge and SolaX as separate AC series. Select a site calendar
day, then load each connected source explicitly. Source filters and date changes
read the cache without fetching. The daily comparison lists each source's reported
energy for the selected month. There is no combined curve, combined energy total,
power integration, household consumption calculation or sample-data mode.

## Provider contracts

| Source | Power | Daily energy | Boundary |
| --- | --- | --- | --- |
| SolarEdge | GET `/site/{siteId}/power`, `unit=W`, `timeUnit=QUARTER_OF_AN_HOUR` | GET `/site/{siteId}/energy`, `timeUnit=DAY`, `unit=Wh` | Site production |
| SolaX | GET `/openapi/v2/device/history_data`, residential `businessType=1`, model 28 `acPower1` in W | POST `/openapi/v2/plant/energy/get_stat_data`, `dateType=2`, monthly `date`, `plantEnergyStatDataList[].inverterACOutputEnergy` in kWh, converted to Wh | Selected inverter power; whole-plant AC output energy |

SolaX's optional MPPT 1/2 power uses the same device history rows and the existing
allowlisted MPPT mapping. Both inputs remain on a separate DC graph. They are
never added to AC power or energy. SolaX plant statistics can cover more devices
than the selected inverter; the screen labels those distinct boundaries.

The SolaX signed-in [reference](https://developer.solaxcloud.com/doc), read on
2026-10-19, defines `inverterACOutputEnergy` as AC-port output energy for the
statistical period. `pvGeneration` is a separate PV energy field. History uses
neither that field nor realtime `dailyACOutput`, `totalACOutput`, `dailyYield`,
`totalYield` or a plant lifetime counter as a replacement. The zero `pvGeneration`
and idle/reset discrepancies documented in [the SolaX investigation](solax-check.md)
do not justify converting missing values to zero or mixing counters. The cause
of the realtime reset/lifetime discrepancies remains unverified in #25. Historical
energy has its own explicit provenance; it does not change Details' live counter.
Selected live values still need comparison with both monitoring portals in #5.

The [SolarEdge Monitoring API reference](https://knowledge-center.solaredge.com/sites/kc/files/se_monitoring_api.pdf)
(March 2026) defines a maximum one-month power request and one-year DAY energy
request. History requests one day of power and one calendar month of daily energy,
sequentially. A source load uses two requests. The published daily limit is 300
requests per account token/site constraints; other phones and clients share quotas.

The SolaX reference permits 5/10/15/30/60-minute history intervals, a maximum
12-hour request duration and queries within the past year. History requests
five-minute readings in sequential UTC windows of at most 12 hours: two windows
on ordinary/spring-transition days and three on a 25-hour day, plus one monthly
statistics request. Today's power query stops at the request's current instant.
A prior package check observed 100 calls/minute and 1,000,000 calls/day; package
limits can vary. A historical day outside the one-year window fails without
making history requests. No retention beyond that contract is promised.

## Time, missing data and caching

Provider site metadata supplies the validated IANA timezone. Phone time is never
used to interpret a provider timestamp. A date selection is a calendar date in
each source's own zone. Different site timezones produce separate graphs. Site
midnight boundaries use the existing IANA database, producing 23/24/25-hour days.
SolaX uses UTC millisecond query bounds and prioritizes the source UTC timestamp.
Ambiguous SolarEdge wall timestamps during a repeated DST hour stay unavailable.
The graph inspector and accessible readings include the timezone abbreviation.

Power is normalized into the requested source cadence. Missing, malformed,
negative, duplicate-bucket and ambiguous-time readings remain gaps. Reported zero
remains zero. No interpolation crosses gaps and daily energy is never calculated
from sampled power. Daily fields are validated separately; missing days remain
unavailable. Today's energy is labeled incomplete and future daily entries are
hidden. The newest cached monthly snapshot replaces older monthly statistics,
including removals, instead of retaining obsolete daily values.

History uses the existing source controller's busy lock and persisted 15-minute
request gate, shared with live refresh/connection testing. It reuses the SolaX
controller's token owner and persists renewal before querying. Provider rate
limits extend the same gate to 24 hours; revoked tokens use the existing reconnect
path. It does not mint separate investigation tokens or retry automatically.
Load failures retain earlier saved history and do not hide the other source.

A separate atomic secure-storage record holds up to 35 source/day snapshots,
bounded across sources and accounts. It contains normalized readings, connection
identity, timezone and receipt time, without keys, secrets, tokens or raw provider
payloads. Cache reads never initiate network requests. Writes are serialized
across sources; a failed write preserves the previous snapshot. Storage-read
failure blocks new history loads until retry succeeds or the owner explicitly
confirms clearing the saved history cache. Clearing preserves connections and
provider request waits. Cached data is labeled
saved with its receipt date/time; reopening a historical day does not imply the
provider has finalized or revised its statistics. Reload explicitly after the
shared request wait. Changing/removing a connection immediately hides histories
whose identity or timezone no longer matches. No historical polling runs in the
background or while offscreen.

## Native verification

`app/integration_test/history_native_test.dart` exercises secure-cache restoration,
corruption detection and the screen with synthetic connections using a separate
storage key. The normal app has no synthetic-data entry point. Screenshots stay
under ignored build output. Run from `app/` with an available Android device:

```sh
flutter drive --driver integration_test/history_driver.dart --target integration_test/history_native_test.dart --keep-app-running -d DEVICE_ID
```

Restore the normal app target after testing. Keep `--keep-app-running` (or
`--no-uninstall` for `flutter test`) to preserve existing connections. Native iOS
verification remains deferred; actual checks and portal-comparison status are
recorded in [ticket 5](tickets/05-history.md).
