## Purpose

Show household consumption only when grid, solar and battery measurements form a valid, time-aligned AC energy balance.

## Description

Deferred household-calculation scope from #7 / PR #41. P1 implementation provides independent timestamped grid import/export; household consumption is intentionally unavailable. The owner confirmed on 2026-10-05 that SolarEdge, SolaX and the battery are all behind this meter. The battery's AC/bypass boundaries and the cross-source timing policy still need verification.

Dependencies: local battery integration #6, P1 implementation #7, and the two existing solar sources (SolarEdge and SolaX). INDEVOLT's SolarEdge card repeats that source; it is not a third solar system. #35 owns Home visualization, #36 owns local history and #8 owns appliance headroom.

Establish a common AC boundary before using solar AC production + signed net grid import + signed battery AC discharge, with export and charging having opposite signs. Do not mix pack DC power with AC readings, double-count bypass/solar, or infer household use from the battery's zero load field or SolaX summary counters. The existing solar freshness window and combined-source skew threshold do not establish a valid instantaneous household balance.

Keep independent P1 readings available when derived household use is unavailable. Preserve measurement times; HTTP receipt time cannot replace an absent source measurement timestamp. Do not clamp inconsistent balances to zero or provide surplus advice from incompatible inputs. See `docs/p1-check.md`, `docs/solax-check.md` and the evidence retained in `docs/tickets/07-house-meter.md`.

## Todo

- [ ] Document battery AC/bypass wiring, solar/grid measurement boundaries and sign conventions using the owner-confirmed shared meter coverage.
- [ ] Verify the required AC fields and loss/availability assumptions across battery charging, discharging and idle; do not substitute pack DC power.
- [ ] Define and test a defensible cross-source timestamp alignment, freshness and unavailable-data policy for the different cloud/local cadences.
- [ ] Implement household consumption only when every required input is compatible and recent; otherwise show an explicit unavailable state while retaining independent grid readings.
- [ ] Test signs, zero versus missing values, stale/skewed timestamps, changed topology and inconsistent balances; suppress unsupported surplus advice.
- [ ] Compare derived consumption with independent measurements across operating modes and record agent-observed versus owner-reported verification.
- [ ] Run the required Flutter/native checks and update this issue/local copy with results and remaining limitations.
