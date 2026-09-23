# Connect Flutter to SolarEdge with protected credentials and sample mode

Replace sample SolarEdge values with real monitoring data after the API check.
Keep source access separate from the screens so PowerFlex and meter data can be
added independently.

## Acceptance criteria

- [x] Choose and document credential handling for this personal app: device secure storage or an authenticated backend; never embed a shared key in app assets/source/build flags.
- [x] Provide connection setup, disconnect, and explicit sample mode.
- [ ] Normalize power (W), energy (Wh), source, timestamp, and availability.
- [ ] Respect verified API limits using caching and a documented refresh interval; avoid per-widget polling.
- [ ] Show connection failures, expired/denied access, rate limiting, and stale data clearly.
- [ ] Redact credential-bearing URLs and response details from logs and crash reports.
- [ ] Verify against the live site and representative failure responses.

Depends on: SolarEdge API check and Flutter setup.

## Progress — 2026-09-22

The owner selected one-time credential entry in Settings on each phone. The
implementation validates the site ID/key with SolarEdge before writing one
protected credential record. It restores the connection at launch, supports
replacement/removal, and keeps the actual key out of code and `.env` files.

The first overview request, safe HTTP errors, explicit sample mode, and an
in-session manual-refresh cooldown are implemented. Unit/widget tests cover
storage lifecycle and failure cases; native storage has a separate integration
test that is pending a mobile toolchain/device. The API itself was verified in #1
using the Python check; a live request from the mobile app remains unverified.

Keep this ticket open for native/live app verification, persistent shared
caching/rate-limit handling as needed, and timezone-aware stale-data behavior.
