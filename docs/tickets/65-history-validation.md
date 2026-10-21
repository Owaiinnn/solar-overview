## Purpose

Complete the historical-reading and native iOS verification deferred from the
production History implementation in #5 and PR #64.

## Description

The owner requested pushing and merging the completed graph work on 2026-10-21
after the real October 19 three-source graph was displayed in Android. Closing
the implementation ticket does not claim that portal comparison or native iOS
verification passed. This ticket preserves those remaining checks explicitly.
The SolaX daily/lifetime and zero-PV counter investigation remains in #25;
Overview/live-power comparison remains in #30, and local battery/grid history
is separate in #36. Do not create a second graph implementation.

Agent verification already passed Flutter 3.47.5 dependency resolution, formatting,
analysis, 314 unit/widget tests, Android secure-cache restoration/corruption and
the AC/DC/missing-source walkthrough, including 360x640 layout at 1.8x text.
The normal Android app displayed real SolarEdge and SolaX power for October 19,
with 245 W + 97 W = 342 W combined at 13:00 CEST. An October 20 SolarEdge power
request returned HTTP 503, while SolaX remained available. These observations
establish live API/UI behavior, not agreement with either monitoring portal.

Power uses SolarEdge site AC production and the selected SolaX inverter's
`acPower1`. Combined power uses matching normalized 15-minute UTC samples;
missing readings remain gaps. SolarEdge daily energy is site Wh, while SolaX
daily energy is whole-plant `inverterACOutputEnergy`, converted from kWh to Wh.
Do not substitute realtime/lifetime, zero PV, battery or DC-input fields.
See `docs/production-history.md` and `docs/solax-check.md` for provenance.

Use the existing saved mobile connections and provider request waits. Issuing a
new SolaX token for the same developer application invalidates the previous one;
do not create independent investigation tokens. Keep credentials, private source
identifiers, raw responses and screenshots out of commits and public issue bodies.

## Todo

- [ ] Compare selected SolarEdge historical power samples and daily energy with its monitoring portal, recording calendar date, site timezone, units and sanitized results.
- [ ] Compare selected SolaX inverter AC samples and whole-plant daily/monthly AC statistics with its monitoring portal; explain coverage differences and preserve missing data.
- [ ] Check the combined graph against matching source samples and confirm that gaps and DST boundaries do not imply complete daily coverage or integrated energy.
- [ ] Record any provider corrections or unresolved discrepancies, linking the SolaX counter investigation in #25 instead of treating it as resolved.
- [ ] When native iOS is available, verify History navigation, date selection, secure-cache restoration, source isolation and persistent request waits; coordinate general device/storage checks with #19 and #25.
- [ ] Record agent-run and owner-run verification separately, without credentials or private raw data.
