## Purpose

Add local INDEVOLT PowerFlex battery monitoring without counting stored energy as
new solar production.

## Description

Discovery and agent-run read-only checks completed on 2026-10-04. This is verified
device access, not a Flutter integration: Settings and Details still contain
battery placeholders. Scope is monitoring only; do not change charging strategies,
limits or operating modes.

The owner confirmed the installation has only two solar sources: SolarEdge and
SolaX, each with panels/inverter. The inverter card in INDEVOLT represents the
existing SolarEdge connection, not a third solar source. The battery is separate;
its exact AC connection/bypass arrangement and measurement boundaries still need
verification before household-flow calculations in #7.

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
belong here; #35 owns the Home animation extension. #7 owns derived household use
and #8 owns appliance advice. #36 owns local battery/grid historical collection.
Recommended implementation order: #6, #7, then #35; #36 is a later milestone.

## Todo

- [x] Identify the INDEVOLT management app and verify local read-only API access from the Mac after owner-enabled HTTP.
- [x] Confirm there are only SolarEdge and SolaX solar sources; do not add the INDEVOLT SolarEdge card as a third source.
- [x] Record observed battery SOC/state/power, AC power, energy fields and unresolved capacity/timestamp semantics without private identifiers or raw responses.
- [ ] Verify exact model, firmware, installed modules, usable capacity and field scaling.
- [ ] Verify pack versus AC/bypass boundaries, charge/discharge signs, state enums, source timing, update cadence and daily counter resets against the app/device.
- [ ] Add an independent local battery client/controller and mobile Settings test/save/replace/remove flow, with secure persistence and source isolation.
- [ ] Handle HTTP authentication errors, timeouts, malformed/missing fields, network changes and changed addresses without replacing good settings on failure; never follow API redirects to another host.
- [ ] Show battery percentage, charging/discharging/idle state, power and qualified energy readings in Details; show available energy only if its capacity/reserve calculation is verified.
- [ ] Implement bounded foreground refresh, cache/restart behavior and local freshness rules, including saved/offline readings away from home without affecting SolarEdge/SolaX waits.
- [ ] Expose normalized battery readings for Home and #7/#8 with explicit provenance; keep battery discharge out of solar totals.
- [ ] Test parsing, signs, missing-versus-zero, stale/unknown time, independent failure/cache/connection lifecycles with synthetic fixtures; keep sample mode absent.
- [ ] Verify live Android connection, comparison with the INDEVOLT app, restart, off-network behavior and return home; preserve existing connections and record agent-run versus owner-run checks.
- [ ] Run required Flutter checks and focused visual verification; carry any uncompleted physical Android/native iOS verification into an explicit follow-up before closing.
