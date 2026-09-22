# Add SolarEdge production history and daily energy graphs

Let the owner inspect production during a day and compare daily energy totals.

## Acceptance criteria

- [ ] Provide a selected-day power graph (W/kW) and daily energy totals (Wh/kWh).
- [ ] Query dates in the site's verified timezone and handle daylight-saving changes.
- [ ] Preserve missing samples as gaps; do not treat missing readings as zero.
- [ ] Cache history and use documented API date-range and request limits.
- [ ] Include readable axis units, loading, empty, and failure states.
- [ ] Verify selected readings against the SolarEdge portal and test date/unit handling.

Depends on: SolarEdge integration.
