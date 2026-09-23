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

Keep this ticket open for persistent caching/rate-limit handling as needed,
timezone-aware stale-data behavior, and remaining failure-path verification.
Inspect the existing normalization/redaction code and tests before implementing
unchecked items: some are partly implemented and require completion/verification,
not a rewrite. Document the limits of any device-local cache across multiple phones;
do not introduce a backend without agreeing its scope with the owner.

Android is the current priority; iOS native verification is deferred under #2 and
should not block this ticket's Android work. Physical Android phone testing remains
a separate pending manual check. Finish this reliability work before expanding #4.

## Todo

- [x] Choose and document credential handling for this personal app: device secure storage or an authenticated backend; never embed a shared key in app assets/source/build flags.
- [x] Provide connection setup, disconnect, and explicit sample mode.
- [ ] Normalize power (W), energy (Wh), source, timestamp, and availability.
- [ ] Respect verified API limits using caching and a documented refresh interval; avoid per-widget polling.
- [ ] Show connection failures, expired/denied access, rate limiting, and stale data clearly.
- [ ] Redact credential-bearing URLs and response details from logs and crash reports.
- [ ] Verify against the live site and representative failure responses.
  - [x] Owner confirmed live connection, persistence and removal on the Android emulator.
  - [ ] Complete representative failure-response verification for the remaining behavior.
