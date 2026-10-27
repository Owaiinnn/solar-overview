# Tibber electricity prices

Tibber is an independent, read-only connection. Settings tests a personal token,
loads the account's homes, and saves only the explicitly selected home. Replacing
or cancelling a connection leaves the previous token and schedule intact until
secure saving succeeds. Removal deletes that token and schedule but retains the
request wait. JSON energy-source import does not import Tibber credentials.

## API and price meaning

The [official schema](https://developer.tibber.com/api/reference.md) and
[API guidance](https://developer.tibber.com/docs/) were checked on 2026-10-27.
Requests use HTTPS POST to `https://api.tibber.com/v1-beta/gql`, bearer authorization,
and GraphQL queries only. Redirects are disabled. Discovery uses `viewer.homes`;
subsequent refreshes use `viewer.home(id:)`. Both fetch today's and tomorrow's
prices together. A request has a 20-second timeout, including response reading.

The selected resolution is passed to `priceInfo`: `QUARTER_HOURLY` (default) or
`HOURLY`. The API requires the explicit quarter-hour option for that resolution.
Settings makes this choice visible; the owner's actual contract resolution still
needs account verification. The app does not infer hourly coverage from missing
quarter-hour records or average records itself.

The screen shows `total`, `energy`, `tax`, and `currency` per kWh. Tibber defines
total as energy plus tax components. The screen does not claim this includes every
contract fee or represents export compensation. The subscription status must be
`running` for a current purchase price; missing or other statuses withhold it.
This status mapping and contract coverage remain subject to live account checking.

## Time, coverage and caching

Offset-bearing `startsAt` values normalize to UTC. Each interval ends after the
explicitly requested duration, never at the next available record. The home IANA
timezone determines local days and displayed UTC offsets. A DST day can contain
23 or 25 hours, or 92 or 100 quarter-hours. Repeated local clock times retain their
different offsets. Price lookup uses inclusive start and exclusive end.

Missing totals remain unavailable, while reported zero and negative prices remain
valid. Duplicate/overlapping intervals, invalid timestamps, nonfinite numbers,
mixed currencies and malformed structures reject the response. Partial GraphQL
errors reject the response even on HTTP 200, retaining the previous saved schedule.
There is no interpolation or extension across a gap. Day lists show unavailable
slots and available/expected counts. Empty tomorrow data is a normal unpublished
or unavailable state. Old cached dates cannot masquerade as today's prices.

One versioned secure-storage record contains the selected token/home, at most 208
intervals, receipt time, refresh deadline, retry gate and authorization state.
Successful refresh replaces the schedule; this is a bounded current/upcoming
cache, not historical bill storage. Startup restores it without a fetch. Failed
storage reads/writes block further network work and offer secure-storage retry.
Only this integration's storage key is touched. Errors omit tokens, home IDs,
URLs and provider response bodies.

## Refresh policy

The app reserves and persists a 15-minute request wait before any network call,
including a test token request. Saving a discovered home makes no extra request.
Cached current prices switch at interval boundaries; a foreground display timer
wakes at most every 30 seconds and sooner for an upcoming price boundary.
Switching tabs or intervals does not itself request prices.

Automatic refresh runs only in the foreground, pauses during connection editing,
and normally waits six hours or until the next home-local midnight, whichever is
sooner. When tomorrow is absent after 13:00 local time it retries hourly. This is
a bounded publication check, not a guarantee of the provider's publication time.
The persisted request gate still takes precedence at midnight and on resume.
Failures back off for 15, 30, 60, then 120 minutes. HTTP 429 waits at least one hour
and honors longer numeric or HTTP-date `Retry-After` values. Authorization failures
stop automatic requests until the connection is replaced. All gates are independent
of SolarEdge, SolaX, P1 and battery waits.

## Verification

Synthetic fixtures live only in tests. Native tests use isolated secure-storage
keys, remove those keys afterwards, and preserve existing energy connections.
Screenshots are ignored build artifacts. See the [ticket](tickets/45-tibber-pricing.md)
for tests actually run and outstanding account/native iOS verification.
