## Purpose

Connect the SolaX panels and inverter to Solar Overview with protected credentials
and reliable readings, independently of the later battery integration.

## Description

Add the SolaX Developer API as a second solar source alongside the existing
SolarEdge connection. This ticket owns connection settings, API access, normalized
readings and source state. Overview presentation belongs to #4; charts and history
belong to #5. PowerFlex battery access remains separate in #6; household measurement
remains in #7. Monitoring only: no device controls or permission changes.

Agent-run read-only checks on 2026-09-28 succeeded against the owner-confirmed EU
API, https://openapi-eu.solaxcloud.com. Authentication, token reuse, plant/device
discovery, current readings, a five-minute history query and monthly daily-energy
statistics worked. One inverter with two MPPT inputs was discovered. The returned
token lifetime was approximately 30 days. At that point, renewal and multi-phone
behavior were unverified; the additional checks below establish current status.

Observed constraints: device readings can be stale despite a successful request;
plant and inverter daily/lifetime energy fields differ; some named production
fields return zero while inverter AC energy is populated. No measured household
consumption or battery telemetry was established. Do not infer those capabilities
from zero counters or plant summary fields. The subsequent reference check
confirmed field units, model/status enums and AC versus PV measurement boundaries.

Implementation is delivered in PR #24:
https://github.com/Owaiinnn/solar-overview/pull/24
The owner approved merging and closing the implementation on 2026-09-30. It adds
independent SolaX settings, paginated plant/device selection, source state and one
secure account/token/selection/reading/cooldown record. The supported scope is EU
residential X1-Micro 2 in 1 (model 28); unsupported models are identified rather
than assigned guessed capabilities. SolarEdge's request budget is unchanged.
No sample mode or live browser credentials were added. Overview and History
presentation beyond connection readings in Settings remain #4/#5.

On 2026-09-29 the agent accessed the official reference through signed-in Chrome:
https://developer.solaxcloud.com/doc. Authentication, monitoring services, units,
model/status codes, renewal and response-driven quota handling were verified.
The public document lookup still failed, but the rendered reference was readable.
The Package page displayed default limits of 100 calls/minute and 1,000,000/day;
these are observed package values, not universal quota guarantees.

A live token check confirmed that issuing a new token invalidates the prior token
for the same application. Each phone must use a separate developer application;
do not reuse a phone's application in scripts or other clients. The app reuses
saved tokens, renews near expiry, and stops automatic renewal on revocation.
Two physical phones with separate applications have not yet been tested.

AC output is `acPower1` (W). MPPT input stays separate. Daily/lifetime energy uses
explicit device `dailyACOutput`/`totalACOutput` (kWh converted to Wh), with PV yield
and plant counters kept distinct. Missing values are unavailable; zero is valid.
The sunset/reset discrepancy remains unresolved and is qualified in Settings.
UTC `dataTime` takes precedence over validated plant-local time; actual `+00:00`
timestamps and the vendor's Amsterdam/Berlin label are covered by regression tests.
The normalized timestamp must not be replaced with the request time.

Agent-run verification on 2026-09-29 passed: pinned Flutter 3.47.5 dependency
resolution, formatting, static analysis, all 107 app unit/widget tests, and Android
API 36 native secure-storage lifecycle tests with isolated synthetic records.
The native test covers connection, restoration across controllers/store instances,
replacement/removal, retained cooldown, and SolarEdge isolation. The new Dart
client also passed real read-only EU discovery/telemetry on the Mac using a saved
Keychain token; source time/timezone, AC/MPPT power, energy and status parsed.
No owner-run SolaX mobile checks have been reported. No live mobile credentials,
raw responses, private IDs/locations or screenshots were committed.

Remaining live Android UI/process-restart, physical Android/two-phone, deferred
iOS and sunset/midnight energy-counter checks have been transferred to #25:
https://github.com/Owaiinnn/solar-overview/issues/25
Those checks have not passed; their linked follow-up preserves the original
scope while this implementation ticket closes with PR #24. Full Xcode remains
unavailable. See `docs/solax-check.md` and `app/README.md` for mappings and setup.

## Todo

- [x] Verify read-only EU API authentication, token reuse, inventory, current readings and representative history queries; record capabilities without secrets or raw responses.
- [x] Verify the vendor's authentication, service permissions, units, status/model enums, quotas and token renewal rules; require only monitoring access.
- [x] Determine whether one application's tokens can coexist on multiple phones; document a supported per-phone setup before rollout.
- [x] Add SolaX connection settings for client ID/secret and verified API region, with test/save, replacement, plant/device selection and removal. Request an app code only if a verified endpoint needs it.
- [x] Store credentials, tokens and any persisted readings in device secure storage, separately from SolarEdge; handle storage failure and prevent data from a replaced account being reused.
- [x] Implement plant/device discovery with pagination and supported-device/capability checks; handle no plants, no devices and denied access clearly.
- [x] Normalize inverter AC power, two MPPT channels, daily/lifetime energy, electrical details, temperature, status and source timestamps; preserve missing values and record field provenance.
- [x] Reuse tokens until renewal is needed, avoid concurrent refresh races, and handle expiration/revocation safely without exposing credentials.
- [x] Implement one coordinated, conservative refresh policy with caching, persistent cooldown/backoff, timeout/rate-limit handling and no per-widget polling; preserve SolarEdge's existing request budget.
- [x] Determine freshness from device/source timestamps, resolve timezone/DST correctly, and retain visibly stale cached readings on failure without treating request time as measurement time.
- [x] Block credential-bearing redirects and redact credentials, tokens, device IDs, locations and raw response/error details from logs and crash reports.
- [x] Test parsing, nulls/zero, source isolation, storage lifecycle, token lifecycle, failures, rate limits and stale/timezone behavior with synthetic fixtures.
- [x] Verify Android native secure save/restore, replacement/removal, persistent cooldown and SolarEdge isolation with separate synthetic records.
- [x] Transfer all remaining live-device, two-phone, iOS and energy-counter checks to linked follow-up #25 before closing this implementation ticket; those checks remain unverified.
