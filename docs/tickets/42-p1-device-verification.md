## Purpose

Complete the physical-device and meter-behavior checks deferred from P1 implementation #7 / PR #41.

## Description

The implementation reads timestamped raw DSMR electricity measurements through the local P1-2WR HTTP API. Real-meter setup, import/export display, full process restart, cached readings, persisted retry waits and automatic network recovery passed on an Android API 36 emulator. The owner confirmed SolarEdge, SolaX and the battery share this meter, and an owner-reported 47 W import matched an agent sample during the comparison.

Device reports firmware `V1.4.0C_R021.102_MP12WR_D0000078`, DSMR version `50` and meter header/model `ISK5\2M550T-1011`; three phase voltage/current fields are present. Four samples spaced ten seconds apart had advancing, current timestamps. This does not establish exact cadence, physical wiring, behavior through a real DST transition or phone roaming.

Preserve existing connections and provider cooldowns. No battery controls or reader settings need to change. Keep private addresses, credentials, screenshots and raw payloads outside git/issues. Existing parser tests cover malformed telegrams, CRC, timestamp/DST, missing values, resets and changed identity; do not claim those synthetic checks as physical-device observations. See `docs/p1-check.md` and the verification evidence retained in `docs/tickets/done/07-house-meter.md`.

Household calculation is separate follow-up work dependent on #6; #35 owns Home visualization and #36 owns local history.

## Todo

- [ ] Verify the physical meter model and phase configuration against the device-reported values.
- [ ] Measure the actual telegram update cadence and stale/repeated-device behavior; verify real DST behavior when feasible, retaining synthetic transition coverage meanwhile.
- [ ] Compare matching-time import/export against the physical meter or vendor app during battery charge, discharge and idle; record agent-observed versus owner-reported results.
- [ ] Resolve aggregate-versus-tariff precision differences before any derived interval/daily totals; retain explicit raw tariff provenance and verify reset/replacement behavior without resetting the actual meter.
- [ ] Verify setup, secure persistence through a full process restart, leaving/returning to the home network and preserved solar connections on a physical Android phone.
- [ ] Verify native iOS local-network permission, local HTTP access, secure persistence, restart and offline recovery with Xcode and a simulator/device.
- [ ] Record evidence, limitations and any fixes in this issue/local copy, and run the required checks for code changes.
