## Purpose

Show dynamic electricity prices from Tibber alongside the solar overview so the
owner can understand the current purchase price and upcoming price periods.

## Description

Owner-requested on 2026-10-05. Add a separate read-only Tibber integration; no
existing pricing ticket covers this. Use the Tibber GraphQL API at
`https://api.tibber.com/v1-beta/gql`, with a personal token entered in mobile
Settings and kept in device secure storage. Never put the token in this issue,
source, fixtures, build flags, logs or screenshots. No live account verification
has been performed for this ticket.

Discover the account's homes and let the owner select one when necessary. Handle
no homes, no current subscription and unavailable prices explicitly. Show the
current interval and today's prices, plus tomorrow when published. Include
currency, price per kWh, interval start/end and data availability. Distinguish
the API's total price from its energy/tax components; verify what the selected
contract includes before calling it an all-in bill cost or export compensation.
Support zero and negative prices without treating them as missing.

The schema supports `priceInfo(resolution: QUARTER_HOURLY)` as well as hourly
resolution. Verify the selected home's supported contract resolution and display
the returned intervals faithfully. Do not assume 24 hourly or 96 quarter-hour
records every day: preserve offsets and the home's time zone across DST. Handle
gaps, duplicate/malformed intervals and a current interval outside cached coverage.

Use an independent client/controller/cache consistent with other sources. Fetch
today/tomorrow together and reuse cached intervals; switching the current price
at an interval boundary must not require a fresh request. Define bounded refresh
around publication/day rollover, retry/backoff and persisted quota handling.
Treat tomorrow-not-yet-published as normal. Handle GraphQL errors even with HTTP
200, authentication failures, 429 responses, timeouts and offline/cached state.
Pricing must not reset solar/battery/P1 waits or block those sources.

This milestone displays prices only. Appliance timing/cost advice is a separately
agreed extension of #8; battery charging automation, switching operating modes,
export compensation and historical bill reconstruction are outside this ticket.

Official references checked on 2026-10-05:
[API schema](https://developer.tibber.com/api/reference.md) and
[calling the API](https://developer.tibber.com/docs/guides/calling-api).

Implementation handoff (2026-10-27): a separate Tibber Settings connection and
Prices tab now support token testing, explicit home selection, atomic secure
saving/replacement, confirmed removal and saved schedules. Queries fetch today's
and tomorrow's intervals together. Current prices switch from cached intervals
at their boundaries without a request. Negative/zero prices, partial coverage,
missing tomorrow, home timezones and DST days are handled explicitly. The cache
and persisted request/refresh gates are independent of all energy sources.
See `docs/tibber-pricing.md` for price provenance, refresh policy and limitations.

Agent-run verification: Flutter 3.47.5 dependency resolution, formatting and
static analysis passed; all 371 unit/widget tests and four Python script tests
passed. The 57 added unit/widget checks cover request/error handling, both
resolutions, DST, malformed/duplicate/missing intervals, secure-record failures,
replacement/cancellation, quota persistence, authorization and offline recovery,
and 360x640 UI at 1.8x text. Android API 36 native testing passed with isolated
synthetic keys: Settings test/save, secure restoration through new store/controller
instances, retained waits, negative/zero prices, missing intervals, simulated
network failure, removal with retained gate and corrupt-storage handling. An
unrelated synthetic secure key was preserved. This is not physical-phone or
OS-process-restoration verification of a real Tibber connection.

The agent inspected the Android captures for Settings, current negative prices,
expanded intervals/gaps and retained prices after a simulated failure. The normal
app was restored, and ADB navigation verified the Prices empty state, its Settings
link and the empty Tibber token/resolution form. Existing energy connections were
not replaced or removed; synthetic keys were cleaned up and captures remain in
ignored build output. No sample mode was added to the normal app.

Remaining acceptance work: no owner Tibber token or account comparison was
available in this session. Authentication against the owner's account, selected
home/subscription, the `running` status mapping, actual contract resolution,
currency and total/component coverage still require live verification. A real
Tibber process restart/offline/recovery comparison and native iOS verification
remain unperformed. No owner-run testing is claimed. Keep #45 open while these
checks remain; the implementation PR does not claim full ticket completion.

## Todo

- [ ] Verify read-only authentication, selected home, subscription, price fields, units, time zone and resolution with the owner's account without retaining private responses.
- [x] Add mobile Settings test/save/replace/remove and home selection with secure persistence and isolation from existing connections.
- [ ] Implement typed price intervals, zero/negative values, currency and verified total/component semantics.
- [x] Show the current price and today's/tomorrow's intervals with clear unavailable, unpublished, saved and offline states.
- [x] Implement cache coverage, publication/day-rollover refresh, independent persisted waits and bounded retries; avoid fetching on each frame or interval change.
- [x] Test DST days, quarter-hour/hourly schedules, interval boundaries, missing tomorrow, partial GraphQL errors, bad credentials, 429, malformed data and restart/offline recovery using synthetic fixtures.
- [ ] Run required Flutter checks and Android secure-storage/visual verification; record account comparison and any deferred native iOS checks.

- [x] Implement typed intervals and separate API total/energy/tax fields without claiming verified contract-wide bill costs.
- [x] Run Flutter checks and isolated Android secure-storage/visual verification; retain outstanding live-account and native iOS checks above.
