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

## Todo

- [ ] Verify read-only authentication, selected home, subscription, price fields, units, time zone and resolution with the owner's account without retaining private responses.
- [ ] Add mobile Settings test/save/replace/remove and home selection with secure persistence and isolation from existing connections.
- [ ] Implement typed price intervals, zero/negative values, currency and verified total/component semantics.
- [ ] Show the current price and today's/tomorrow's intervals with clear unavailable, unpublished, saved and offline states.
- [ ] Implement cache coverage, publication/day-rollover refresh, independent persisted waits and bounded retries; avoid fetching on each frame or interval change.
- [ ] Test DST days, quarter-hour/hourly schedules, interval boundaries, missing tomorrow, partial GraphQL errors, bad credentials, 429, malformed data and restart/offline recovery using synthetic fixtures.
- [ ] Run required Flutter checks and Android secure-storage/visual verification; record account comparison and any deferred native iOS checks.
