## Purpose

Give the owner a clear, trustworthy view of current solar production and available data sources.

## Description

Show useful SolarEdge readings immediately, while clearly indicating which other
sources are not connected yet.

Depends on: Flutter setup and SolarEdge integration.

## Todo

- [ ] Show SolarEdge current production, today's energy, and last update.
- [ ] Distinguish live-source data, sample data, missing data, and stale data.
- [ ] Show PowerFlex, battery, and household consumption as unavailable until connected.
- [ ] Do not label SolarEdge alone as combined production or calculate household surplus without the required inputs.
- [ ] Explain W/kW versus Wh/kWh with concise labels.
- [ ] Verify the layout on Android and iOS screen sizes, including larger text.
