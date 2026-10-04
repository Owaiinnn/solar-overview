## Purpose

Complete real-device and measurement validation for the local INDEVOLT battery integration while keeping unverified battery data out of household calculations.

## Description

Follow-up to implementation ticket #6 and PR #39, created for the owner's requested merge on 2026-10-06. The read-only client, independent secure cache, Settings/Details and bounded foreground refresh are implemented. Earlier agent-run checks verified Mac HTTP access, Android emulator native secure storage, synthetic native HTTP and battery setup/Details UI. These do not establish physical-device behavior or measurement semantics.

Preserve ticket #6's outstanding scope: prior-chat/device evidence, exact model, firmware/modules/capacity, charge/discharge/idle comparisons, pack DC versus AC/bypass boundaries, source timing/cadence and daily counter resets. Receipt age is not source measurement time; no verified usable-energy or household-balance claim is allowed. Household calculations belong to #43, Home graphics to #35 and history to #36.

Use home-network-only HTTP and preserve saved connections and cloud cooldowns. Enter addresses/credentials only through Settings; do not upload private screenshots, raw responses or identifiers. Use --no-uninstall for Flutter integration tests and --keep-app-running for flutter drive. Distinguish agent-run checks from owner-reported evidence. Native iOS checks may remain deferred without blocking Android work.

## Todo

- [ ] Verify exact model, firmware, installed modules, usable versus rated capacity and field scaling using device evidence.
- [ ] Compare live SOC and charge/discharge/idle states against the INDEVOLT app, including sign conventions and inconsistent readings.
- [ ] Verify pack DC versus inverter/total AC and bypass boundaries; record what remains unsuitable for household balance in #43.
- [ ] Establish source timestamp availability, update cadence and stale-device behavior; verify daily charge/discharge counter units, completeness and reset behavior.
- [ ] Verify physical Android live connection, saved readings after restart, off-network failure/backoff and recovery on returning home without resetting solar waits.
- [ ] Verify iOS local-network permission/HTTP access, secure persistence, foreground/background refresh and Settings/Details on a simulator or device.
- [ ] Record evidence and remaining limitations in docs/battery-check.md and this ticket without private data; update normalization only when supported by verified findings.
