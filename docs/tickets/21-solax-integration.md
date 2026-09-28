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
token lifetime was approximately 30 days; refresh and multi-phone token behavior
have not been verified. This proves API access, not a working Flutter integration.

Observed constraints: device readings can be stale despite a successful request;
plant and inverter daily/lifetime energy fields differ; some named production
fields return zero while inverter AC energy is populated. No measured household
consumption or battery telemetry was established. Do not infer those capabilities
from zero counters or plant summary fields. Confirm field units, model/status
enums and physical measurement boundaries before mapping them into the app.

The current Flutter code only has SolarEdge source/controller/storage and settings.
Keep that working while adding independent SolaX state. Android first; retain iOS
support and explicitly track device verification that cannot yet be run. No sample
mode or live browser credentials; synthetic readings belong only in tests.

Reference: https://developer.solaxcloud.com/doc. The public documentation lookup
failed during the probe; vendor limits and semantics still need verification.
The local probe is investigation tooling, not a production client.

## Todo

- [x] Verify read-only EU API authentication, token reuse, inventory, current readings and representative history queries; record capabilities without secrets or raw responses.
- [ ] Verify the vendor's authentication, service permissions, units, status/model enums, quotas and token renewal rules; require only monitoring access.
- [ ] Determine whether one application's tokens can coexist on multiple phones; document a supported per-phone setup before rollout.
- [ ] Add SolaX connection settings for client ID/secret and verified API region, with test/save, replacement, plant/device selection and removal. Request an app code only if a verified endpoint needs it.
- [ ] Store credentials, tokens and any persisted readings in device secure storage, separately from SolarEdge; handle storage failure and prevent data from a replaced account being reused.
- [ ] Implement plant/device discovery with pagination and supported-device/capability checks; handle no plants, no devices and denied access clearly.
- [ ] Normalize inverter AC power, two MPPT channels, daily/lifetime energy, electrical details, temperature, status and source timestamps; preserve missing values and record field provenance.
- [ ] Investigate plant/device energy discrepancies and end-of-day behavior; choose explicit energy fields without silently swapping sources or converting unavailable values to zero.
- [ ] Reuse tokens until renewal is needed, avoid concurrent refresh races, and handle expiration/revocation safely without exposing credentials.
- [ ] Implement one coordinated, conservative refresh policy with caching, persistent cooldown/backoff, timeout/rate-limit handling and no per-widget polling; preserve SolarEdge's existing request budget.
- [ ] Determine freshness from device/source timestamps, resolve timezone/DST correctly, and retain visibly stale cached readings on failure without treating request time as measurement time.
- [ ] Block credential-bearing redirects and redact credentials, tokens, device IDs, locations and raw response/error details from logs and crash reports.
- [ ] Test parsing, nulls/zero, source isolation, storage lifecycle, token lifecycle, failures, rate limits and stale/timezone behavior with synthetic fixtures.
- [ ] Verify connection, restart persistence, replacement/removal and source isolation on Android; record live checks separately from synthetic tests and track deferred physical-device/iOS checks explicitly.
