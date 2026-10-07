## Purpose

Complete the physical-device and meter-behavior checks deferred from P1 implementation #7 / PR #41.

## Description

The implementation reads timestamped raw DSMR electricity measurements through the local P1-2WR HTTP API. Real-meter setup, import/export display, full process restart, cached readings, persisted retry waits and automatic network recovery passed on an Android API 36 emulator. The owner confirmed SolarEdge, SolaX and the battery share this meter, and an owner-reported 47 W import matched an agent sample during the comparison.

Device reports firmware `V1.4.0C_R021.102_MP12WR_D0000078`, DSMR version `50` and meter header/model `ISK5\2M550T-1011`; three phase voltage/current fields are present. Four samples spaced ten seconds apart had advancing, current timestamps. This does not establish exact cadence, physical wiring, behavior through a real DST transition or phone roaming.

Preserve existing connections and provider cooldowns. No battery controls or reader settings need to change. Keep private addresses, credentials, screenshots and raw payloads outside git/issues. Existing parser tests cover malformed telegrams, CRC, timestamp/DST, missing values, resets and changed identity; do not claim those synthetic checks as physical-device observations. See `docs/p1-check.md` and the verification evidence retained in `docs/tickets/done/07-house-meter.md`.

Household calculation is separate follow-up work dependent on #6; #35 owns Home visualization and #36 owns local history.

Resumed home-network verification on 2026-10-07 (Europe/Amsterdam): both local APIs responded after the owner returned home. The agent retained 35 P1 samples at roughly one-second intervals from 18:46:39 to 18:47:13; all 34 successive source-timestamp steps were one second, receipt ages 2.093–2.424 seconds and import 1,587–2,246 W. This is observed cadence for that window, not verified stale/repeated-device or DST behavior.

Real-reader Android API 36 emulator checks passed again alongside the battery integration: Settings setup, import display and advancing timestamps, saved data on network loss, full process restart, persisted retry deadline and automatic network recovery. The P1 countdown went from 55 seconds before restart at 18:56:45 to 30 seconds at 18:57:10; both local sources recovered by 18:58:10. A second failed request had increased backoff to about two minutes. Solar connections/cooldowns were retained. Emulator Wi-Fi/mobile data were restored to their original enabled states. A private helper assertion interrupted the first sequence after force-stop; cleanup restored networking and restart/recovery were verified separately. No physical Android phone or Xcode/iOS environment was available.

The owner's 18:59 INDEVOLT overview showed export 116 W and battery 43%/Standby/26 W. Eight agent probe pairs during 18:59:18–18:59:56 instead showed import 1,477–1,612 W, zero export and battery 40.0–40.1% discharging at about 694 W. Overview staleness is a hypothesis; after a refresh/reopen request the owner reported “40% now”, but no updated grid reading or exact sample time. Independent grid agreement remains unverified; do not reverse signs or infer household use from this screenshot.

On the owner's requested recheck at 19:06:27, P1 reported export 1,761 W, import zero and meter time 19:06:26; battery discharge had risen to 2,451 W pack DC. At 19:07:53 export was 1,878 W with meter time 19:07:52. The agent visually verified the app displaying export 1.881 kW from meter time 19:07:27. Later actual export does not validate the earlier mismatched screenshot. Evidence is in docs/p1-check.md; battery-specific follow-up remains #53. No app code changed; documentation checks cover links, required ticket headers and diff cleanliness, with no app-test rerun.

## Todo

- [ ] Verify the physical meter model and phase configuration against the device-reported values.
- [ ] Measure the actual telegram update cadence and stale/repeated-device behavior; verify real DST behavior when feasible, retaining synthetic transition coverage meanwhile.
- [x] Record a retained live cadence sample: 35 responses with one-second timestamp advancement on 2026-10-07.
- [ ] Compare matching-time import/export against the physical meter or vendor app during battery charge, discharge and idle; record agent-observed versus owner-reported results.
- [ ] Resolve aggregate-versus-tariff precision differences before any derived interval/daily totals; retain explicit raw tariff provenance and verify reset/replacement behavior without resetting the actual meter.
- [ ] Verify setup, secure persistence through a full process restart, leaving/returning to the home network and preserved solar connections on a physical Android phone.
- [x] Recheck real-meter setup, import/export display, full restart, persisted retry waits and network recovery on the Android emulator with battery and solar connections preserved.
- [ ] Verify native iOS local-network permission, local HTTP access, secure persistence, restart and offline recovery with Xcode and a simulator/device.
- [ ] Record evidence, limitations and any fixes in this issue/local copy, and run the required checks for code changes.
