# Connect Flutter to SolarEdge with protected credentials and sample mode

Replace sample SolarEdge values with real monitoring data after the API check.
Keep source access separate from the screens so PowerFlex and meter data can be
added independently.

## Acceptance criteria

- [ ] Choose and document credential handling for this personal app: device secure storage or an authenticated backend; never embed a shared key in app assets/source/build flags.
- [ ] Provide connection setup, disconnect, and explicit sample mode.
- [ ] Normalize power (W), energy (Wh), source, timestamp, and availability.
- [ ] Respect verified API limits using caching and a documented refresh interval; avoid per-widget polling.
- [ ] Show connection failures, expired/denied access, rate limiting, and stale data clearly.
- [ ] Redact credential-bearing URLs and response details from logs and crash reports.
- [ ] Verify against the live site and representative failure responses.

Depends on: SolarEdge API check and Flutter setup.
