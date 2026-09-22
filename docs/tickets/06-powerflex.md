# Investigate and connect the PowerFlex battery system and its two panels

The second solar source is a PowerFlex 2000Eco home battery system with its own
inverter and two dedicated panels. API information is not yet available.

## Acceptance criteria

- [ ] Confirm manufacturer, management app, usable capacity, and supported read-only data access.
- [ ] Document available fields, units, update intervals, and access constraints.
- [ ] Distinguish panel production, battery charge/discharge, and inverter output; if the source cannot separate them, show the limitation instead of inventing solar production.
- [ ] Show battery state of charge when available.
- [ ] Combine compatible solar production readings from both systems without double counting or treating battery discharge as new solar production.
- [ ] Handle source time differences, outages, and stale readings.
- [ ] Verify against the battery app using actual data.

Depends on: Flutter data-source structure. Hardware/API identification is pending;
this does not block the first SolarEdge milestone. Scope is monitoring only.
