## Purpose

Add PowerFlex battery monitoring later without confusing stored energy with new
solar production.

## Description

The owner clarified on 2026-09-28 that the tested SolaX API covers panels and
inverter, while the battery will use a separate integration later. SolaX connection
work belongs to #21, solar overview work to #4, and solar history to #5. This ticket
now focuses on the PowerFlex 2000Eco battery; it must not block the SolaX work.

The battery's management app, supported API and exact electrical relationship to
the solar inverters still need confirmation. Do not assume SolaX's zero battery
counters describe the physical battery. Preserve any discovered PV/battery/output
measurement distinctions, but do not duplicate solar-source implementation here.

Depends on: Flutter data-source structure. Hardware/API identification is pending;
this does not block the first SolarEdge milestone. Scope is monitoring only.

## Todo

- [ ] Confirm manufacturer, management app, usable capacity, and supported read-only data access.
- [ ] Document available fields, units, update intervals, and access constraints.
- [ ] Document battery topology and distinguish any reported panel input, battery charge/discharge and inverter output; expose limitations instead of treating battery discharge as solar generation.
- [ ] Show battery state of charge when available.
- [ ] Add independent battery connection, secure storage, failure and removal handling without affecting either solar connection.
- [ ] Show charging/discharging power and available energy when supported, with verified units, signs, source timestamps and availability.
- [ ] Integrate battery flows with the overview and future household/headroom calculations without double counting solar production; solar combination itself belongs to #4.
- [ ] Handle source time differences, outages, and stale readings.
- [ ] Verify against the battery app using actual data.
