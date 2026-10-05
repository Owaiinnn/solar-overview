## Purpose

Connect the app to real SolarEdge readings without embedding or exposing the owner's credentials.

## Description

Replace sample SolarEdge values with real monitoring data after the API check.
Keep source access separate from the screens so PowerFlex and meter data can be
added independently.

Depends on: SolarEdge API check and Flutter setup.

Progress — 2026-09-23:

The owner selected one-time credential entry in Settings on each phone. The
implementation validates the site ID/key with SolarEdge before writing one
protected credential record. It restores the connection at launch, supports
replacement/removal, and keeps the actual key out of code and `.env` files.

The first overview request, safe HTTP errors, explicit sample mode, and an
in-session manual-refresh cooldown are implemented. All 21 unit/widget tests cover
storage lifecycle, failure cases and sample preview behavior. The separate native
storage integration test passed on Android API 36 with a synthetic record; iOS
native verification remains pending. PR #10 was merged on 2026-09-23. The API
itself was verified in #1 using the Python check. The owner subsequently confirmed
that a live SolarEdge connection updates both screens on the Android emulator,
credentials persist after fully closing/reopening the app, and removal works.
These manual results are user-reported; physical Android phone testing is pending.

Progress — 2026-09-28:

The remaining reliability implementation was merged on 2026-09-28 in
[PR #18](https://github.com/Owaiinnn/solar-overview/pull/18). A secure normalized snapshot and refresh deadline
survive restarts; startup, refresh and connection tests share a 15-minute wait.
Each attempt uses up to two sequential requests (overview and site details),
allowing 192 requests per day on one phone against the documented 300-request
quota. HTTP 429 persists a conservative 24-hour pause. Multiple phones/apps share
the provider quota but do not share this device-local limiter; there is no backend.
Storage failures block new requests until recovery. Disconnect removes the key
and readings while preserving the wait; replacement cannot reuse an old snapshot.

Power/energy remain W/Wh with explicit null availability. Site timezone and a
validated UTC timestamp support stale detection at 30 minutes. Unknown/future or
DST-ambiguous timestamps never look fresh. Today's energy is unavailable for a
previous site date. Cached readings remain visible after network failures, with
clear saved/stale/error states. Freshness updates on resume and each minute without
network polling. Sample mode was removed at the owner's request under #2; it has
not been reintroduced.

Agent-run verification: Flutter 3.47.5 dependency resolution, formatting, analysis,
53 unit/widget tests, four Python script tests, Android debug build and launch,
and both native secure-storage integration tests passed on the API 36 emulator.
Fixtures cover 401/403, 429, redirects, server/network/timeout errors, malformed
responses, restart caching, failed storage/recovery, concurrent actions, timezone
aliases, DST changes, future dates, midnight rollover, and small screens with
larger text. Native tests use isolated synthetic records; they do not exercise
real credentials. The earlier live-site verification above remains user-reported.

Closure — 2026-09-28:

PR #18 is merged and its GitHub Checks passed. At the owner’s request, close
this merged implementation ticket. The new live site-timezone/cache verification,
physical Android testing and deferred iOS checks are preserved in
[#19](https://github.com/Owaiinnn/solar-overview/issues/19). Those checks remain
pending; earlier user-reported live checks and automated synthetic checks are
listed above and do not substitute for them.

Implementation policy and official API reference:
[refresh, caching and freshness](https://github.com/Owaiinnn/solar-overview/blob/main/app/README.md#refresh-saved-readings-and-freshness).

## Todo

- [x] Choose and document credential handling for this personal app: device secure storage or an authenticated backend; never embed a shared key in app assets/source/build flags.
- [x] Provide connection setup and disconnect; sample mode was delivered initially and subsequently removed at the owner's request in #2.
- [x] Normalize power (W), energy (Wh), source, timestamp, and availability.
- [x] Respect verified API limits using caching and a documented refresh interval; avoid per-widget polling.
- [x] Show connection failures, expired/denied access, rate limiting, and stale data clearly.
- [x] Redact credential-bearing URLs and response details from logs and crash reports.
- [x] Verify the initial live connection and representative failure responses; track new live-flow checks separately in #19.
  - [x] Owner confirmed live connection, persistence and removal on the Android emulator.
  - [x] Complete representative failure-response verification for the remaining behavior.
  - [x] Carry forward pending live site-timezone and persistent-cache confirmation on Android to #19.
