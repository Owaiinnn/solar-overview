## Purpose

Help the owner estimate whether additional appliances can run on currently available solar power.

## Description

Allow the owner to select additional appliances and estimate whether available
solar power can cover their combined demand at the current moment.

Depends on: overview and appliance profiles; reliable live advice additionally
requires verified household/grid measurement (#7) and every flow needed for the
chosen calculation. Solar production comes from SolarEdge and SolaX (#21/#4).
Battery support is deferred to #6; do not estimate unmeasured battery flows as zero.
Profile editing can proceed before complete telemetry, but withhold live headroom
where its inputs are incomplete. The app's sample mode was removed in #2.

## Todo

- [ ] Add/edit saved appliance profiles, including dishwasher and washing machine, with clearly labelled estimated power and cycle duration.
- [ ] Selecting appliances updates estimated demand and remaining headroom.
- [ ] Avoid double counting appliances already running within measured household consumption.
- [ ] Confirm whether battery support is allowed and whether battery charging/reserve takes priority.
- [ ] Include a configurable reserve for changing production and household demand.
- [ ] Explain that appliance heating phases and clouds can change demand/supply during a cycle; do not guarantee a solar-only full cycle.
- [ ] Verify calculations for both sources, battery flows, negative surplus, and stale/missing inputs.
- [ ] Withhold live headroom/advice when required solar, household or battery-flow inputs are missing, stale or incompatible; explain which source is needed.
- [ ] Keep sample mode absent; use synthetic scenarios only in tests.
