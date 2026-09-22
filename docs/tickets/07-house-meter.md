# Identify the smart meter and connect household consumption

A smart meter is installed, but its model and available reader are unknown.
Establish what it measures before using it in appliance calculations.

## Acceptance criteria

- [ ] Identify the meter, any P1 reader, and any existing Home Assistant setup.
- [ ] Document whether readings represent whole-house consumption or net grid import/export.
- [ ] Obtain timestamped readings through a supported read-only interface.
- [ ] If consumption must be derived, document the measurement boundaries, sign conventions, battery flows, and conversion/loss assumptions.
- [ ] Avoid mixing DC panel input and AC grid readings as though they were identical measurements.
- [ ] Validate signs and totals during import, export, battery charge, and battery discharge where observable.
- [ ] Suppress surplus advice when required inputs are stale, missing, or incompatible.

Depends on: meter identification and the shared data-source structure; derived
consumption may also depend on PowerFlex telemetry.
