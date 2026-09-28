## Purpose

Obtain reliable household consumption data for the overview and appliance calculations.

## Description

A smart meter is installed, but its model and available reader are unknown.
Establish what it measures before using it in appliance calculations.

The SolaX read-only probe on 2026-09-28 did not establish household measurement:
no meter device was returned, grid power was unavailable, and historical
`loadConsumption` matched inverter output rather than independently measured
household use. Do not use that field or zero import/export counters as proof of
whole-house consumption or zero grid flow. SolaX panel/inverter integration is #21;
battery access remains separate, deferred work in #6.

Depends on: meter identification and the shared data-source structure; derived
consumption may also depend on PowerFlex telemetry.

## Todo

- [ ] Identify the meter, any P1 reader, and any existing Home Assistant setup.
- [ ] Document whether readings represent whole-house consumption or net grid import/export.
- [ ] Confirm coverage of both the SolarEdge and SolaX sources and the separate battery; do not substitute inverter AC output or SolaX summary load counters for measured consumption.
- [ ] Obtain timestamped readings through a supported read-only interface.
- [ ] If consumption must be derived, document the measurement boundaries, sign conventions, battery flows, and conversion/loss assumptions.
- [ ] Avoid mixing DC panel input and AC grid readings as though they were identical measurements.
- [ ] Validate signs and totals during import, export, battery charge, and battery discharge where observable.
- [ ] Suppress surplus advice when required inputs are stale, missing, or incompatible.
