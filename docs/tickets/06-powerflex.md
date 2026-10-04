## Purpose

Add local INDEVOLT PowerFlex battery monitoring without counting stored energy as
new solar production.

## Description

Discovery and agent-run read-only checks completed on 2026-10-04. This is verified
device access. The Flutter implementation is now on `feat/6-local-battery`;
Settings and Details contain the local battery connection and readings. Scope is monitoring only; do not change charging strategies,
limits or operating modes.

The owner confirmed the installation has only two solar sources: SolarEdge and
SolaX, each with panels/inverter. The inverter card in INDEVOLT represents the
existing SolarEdge connection, not a third solar source. The battery is separate;
its exact AC connection/bypass arrangement and measurement boundaries still need
verification before household-flow calculations in #43.

The owner enabled HTTP in the INDEVOLT app and chose home-network access for now.
The Mac successfully read `POST /rpc/Indevolt.GetData` on port 8080 with a `config`
query containing the requested `t` points. Earlier HTTP Digest requests returned
401; HTTP returned 200. Device address is entered locally, not committed. Explain
that this HTTP mode permits local-network API access without authentication.
Cloud/MQTT, a hosted service and remote access are outside this milestone.

Verified fields and remaining qualifications:

- `9405`: system SOC (%); `6001`: battery state (1000 idle, 1001 charging,
  1002 discharging); `6000`: battery-pack power (W), documented positive discharge
  and negative charge. A live negative-power sample agreed with charging state;
  live discharge/idle transitions and comparison with the app remain untested.
- `2275` and `2278`: AC-side power, documented positive charge/input and negative
  discharge/output; total AC power can include bypass flow. These differed from
  pack power in the live charging sample. Do not use pack DC power as AC flow or
  assume either AC field is solar production.
- `6004`/`6005`: daily charge/discharge energy fields, documented kWh; daily resets,
  completeness and agreement with the app still need verification.
- `142` returned a capacity value of 6.05. The reference mixes kWh and Wh wording:
  confirm scaling, module configuration and rated versus usable capacity. Do not
  promise available energy by multiplying this unverified capacity by SOC.
- `7120` reported enabled and `11016` returned a meter value. Prefer the direct
  P1 meter integration in #7 for whole-meter grid readings; coverage/sign of this
  hub field is not established. `5000` returned zero; that does not establish zero
  household consumption.
- No source measurement timestamp or stale-device behavior was established for
  battery telemetry. Distinguish receipt time from source time, determine update
  cadence and a suitable local freshness policy, and suppress unsupported flows.

References: [HTTP setup](https://docs.indevolt.com/docs/hardware/open-data/http/)
and [field reference](https://docs.indevolt.com/docs/hardware/open-data/http-api/).
The project previously identified the battery as PowerFlex 2000Eco; retrieve and
verify the exact model, firmware and installed modules during implementation.

Implementation should reuse the app's independent source/controller pattern,
with local address setup, test/save/replace/remove, cached readings and isolated
failures. A local source must not consume/reset cloud-provider refresh waits.
Use bounded foreground refresh with a documented cadence/backoff; no background
polling. Away from home, show saved values with age and unavailable/stale status,
never a current charge/discharge claim. Verify Android local HTTP/network access;
retain iOS support and explicitly track native verification limitations.

Dependencies: merged solar foundation #3/#21/#4. Basic battery readings in Details
belong here; #35 owns the Home animation extension. #43 owns derived household use
and #8 owns appliance advice. #36 owns local battery/grid historical collection.
Recommended implementation order: #6, #7, then #35; #36 is a later milestone.

Implementation handoff (2026-10-04):

- Independent read-only client, secure atomic connection/cache record, Settings
  test/save/replace/remove and battery Details implemented. Only private IPv4
  addresses on port 8080 are accepted; redirects are rejected. Failures retain
  the previous address and readings. No battery values enter solar totals.
- Foreground cadence is 30 seconds, with 1/2/4/5-minute failure backoff persisted
  across restarts. Replacement editing pauses automatic refresh. A 90-second
  receipt window is an app policy, not verified device freshness. Source time
  remains unknown and normalized readings explicitly disallow household balance.
- Agent-run checks: Flutter 3.47.5 dependency resolution, formatting, analysis,
  150 unit/widget tests; Android API 36 native secure-storage lifecycle/isolation
  and native HTTP against a synthetic on-device server (including 302/401).
  Focused agent-controlled emulator walkthrough verified battery setup layout,
  empty-address validation and the Details connection card/navigation.
  No real battery connection was attempted during implementation: the owner is
  away from the home network and is gathering a prior-chat handoff.
- Native test-runner default uninstall temporarily removed emulator connections.
  The existing emulator snapshot recovered both solar connections. Project test
  instructions now require `--no-uninstall` / `--keep-app-running`.
- Remaining: prior-chat/device evidence for model, firmware/modules/capacity,
  physical Android live connection and INDEVOLT comparison, charge/discharge/idle
  transitions, actual off-network/return-home behavior and counter reset/timing;
  native iOS verification. These checks are now explicitly carried forward in #53 for the
  owner-requested merge of PR #39; implementation closure does not claim they passed. Home animation remains in #35.
- Policy, field provenance and native setup: [battery notes](../battery-check.md).

Merge preparation (2026-10-06):

- Owner explicitly requested merging PR #39 and refactor PR #52. #52 is merged;
  battery integration is reconciled with the refactored Settings composition and
  existing P1 monitoring. Both local sources retain independent controllers,
  storage and foreground timers; solar production remains separate.
- Outstanding model/capacity, physical-device, measurement and native iOS checks
  are preserved in open follow-up #53 (docs/tickets/53-battery-device-verification.md).
  The unchecked verification items below remain evidence of work not yet run.
- Agent reran Flutter 3.47.5 dependency resolution, formatting, analysis and all
  195 unit/widget tests after conflict resolution. A combined-source regression
  checks independent P1/battery polling and background pause without solar requests.
- Agent reran both battery native integration tests on Android API 36 with
  `--no-uninstall`: secure-storage lifecycle/isolation and synthetic HTTP telemetry,
  redirect rejection and authentication errors passed. The normal app was restored
  afterward. The iOS plist passed syntax validation; native iOS remains in #53.
- Agent visually verified the combined app's Home, Settings P1/battery cards,
  empty battery-address validation and both local-source Details cards with the
  unavailable-household explanation. Existing solar connections were preserved;
  no real battery connection or live battery comparison was attempted.
- GitHub could not rebase the merge commit, so the same verified file tree was
  rebuilt as three logical commits atop current main. A full tree diff confirmed
  identical contents before this documentation update.

## Todo

- [x] Identify the INDEVOLT management app and verify local read-only API access from the Mac after owner-enabled HTTP.
- [x] Confirm there are only SolarEdge and SolaX solar sources; do not add the INDEVOLT SolarEdge card as a third source.
- [x] Record observed battery SOC/state/power, AC power, energy fields and unresolved capacity/timestamp semantics without private identifiers or raw responses.
- [ ] Verify exact model, firmware, installed modules, usable capacity and field scaling.
- [ ] Verify pack versus AC/bypass boundaries, charge/discharge signs, state enums, source timing, update cadence and daily counter resets against the app/device.
- [x] Add an independent local battery client/controller and mobile Settings test/save/replace/remove flow, with secure persistence and source isolation.
- [x] Handle HTTP authentication errors, timeouts, malformed/missing fields, network changes and changed addresses without replacing good settings on failure; never follow API redirects to another host.
- [x] Show battery percentage, charging/discharging/idle state, power and qualified energy readings in Details; show available energy only if its capacity/reserve calculation is verified.
- [x] Implement bounded foreground refresh, cache/restart behavior and local freshness rules, including saved/offline readings away from home without affecting SolarEdge/SolaX waits.
- [x] Expose normalized battery readings for Home and #7/#8 with explicit provenance; keep battery discharge out of solar totals.
- [x] Test parsing, signs, missing-versus-zero, stale/unknown time, independent failure/cache/connection lifecycles with synthetic fixtures; keep sample mode absent.
- [ ] Verify live Android connection, comparison with the INDEVOLT app, restart, off-network behavior and return home; preserve existing connections and record agent-run versus owner-run checks.
- [x] Run required Flutter checks and focused visual verification (2026-10-04 evidence above, with merged-code checks recorded here); carry uncompleted physical Android/native iOS and measurement verification into #53 before closing.
