## Purpose

Help the owner estimate whether additional appliances can run on currently available solar power.

## Description

Allow the owner to select additional appliances and estimate whether available
solar power can cover their combined demand at the current moment.

Depends on: overview and appliance profiles; reliable live advice additionally
requires verified household/grid measurement (#7) and every flow needed for the
chosen calculation. Solar production comes from SolarEdge and SolaX (#21/#4).
Battery and direct P1 API access were verified from the Mac on 2026-10-04;
the mobile integrations remain open in #6/#7. Do not estimate missing flows as zero.
The installation still has only two solar sources: the SolarEdge card in INDEVOLT
is not additional production.
Profile editing can proceed before complete telemetry, but withhold live headroom
where its inputs are incomplete. The app's sample mode was removed in #2.

The P1 reading is net grid exchange. Export alone does not prove spare solar:
battery discharge can contribute, while battery charging may have priority.
Use #7's verified boundaries/time alignment and the battery-reserve policy before
classifying headroom. Fast local readings must not be combined with older cloud
solar samples as though they describe one instant. The Home visualization in #35
is presentation, not an independent headroom calculator. Local access is the
chosen scope: away from home, withhold live advice when local inputs are absent.

## Todo

- [ ] Add/edit saved appliance profiles, including dishwasher and washing machine, with clearly labelled estimated power and cycle duration.
- [ ] Selecting appliances updates estimated demand and remaining headroom.
- [ ] Avoid double counting appliances already running within measured household consumption.
- [ ] Confirm whether battery support is allowed and whether battery charging/reserve takes priority.
- [ ] Include a configurable reserve for changing production and household demand.
- [ ] Explain that appliance heating phases and clouds can change demand/supply during a cycle; do not guarantee a solar-only full cycle.
- [ ] Verify calculations for both solar sources, battery charge/discharge priority, grid export partly supplied by battery, negative surplus, timestamp mismatch and stale/missing/off-network inputs.
- [ ] Withhold live headroom/advice when required solar, household or battery-flow inputs are missing, stale or incompatible; explain which source is needed.
- [ ] Keep sample mode absent; use synthetic scenarios only in tests.
