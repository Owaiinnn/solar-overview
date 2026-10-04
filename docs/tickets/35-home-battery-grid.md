## Purpose

Extend the existing animated house so the owner can see battery charge/status and
grid import/export at a glance alongside the two solar sources.

## Description

Owner-requested follow-up on 2026-10-04 to the merged Home scene in #28 / PR #33.
Reuse the original green/ivory house, roof panels, sun rays, loading bounce and
Home-to-Details navigation. Do not reopen #28 or the superseded bolt ticket #11.
The current scene only accepts solar production/loading state; battery and meter
support are not implemented. Mac API checks in #6/#7 establish access, not app UI.

There are only two solar sources: SolarEdge and SolaX. The inverter card in the
INDEVOLT app repeats the existing SolarEdge system. Add the separate battery and
P1 grid meter to the presentation, never a third solar source or a battery-derived
solar total. Use the normalized, independently cached sources from #6/#7; the
scene must not query APIs, create a refresh loop or change cloud cooldowns.

Show a battery shape beside the existing house, a fill level driven by valid SOC,
a readable percentage, and Charging / Discharging / Idle / Unavailable status.
Include charging/discharging power where verified. Animate movement into the
battery during eligible charging and out during eligible discharge; idle is still.
SOC must not determine the operating state: a high/low percentage is not proof of
charging/discharging. Keep a last-known percentage visibly qualified when stale,
and stop directional movement on stale, offline, unknown or inconsistent data.

Add a compact grid indicator with Importing / Exporting / No net exchange and
verified W/kW. Animate grid-to-house or house-to-grid direction only when the
meter source is eligible; zero is distinct from unavailable. Show household use
only when #7's measurement coverage, AC boundaries and timestamp alignment are
satisfied. Otherwise omit the number or explain unavailable consumption without
blocking independent battery/grid readings. Do not imply the battery is charging
from solar specifically: grid charging is possible and source attribution is not
established by direction alone. The illustration remains schematic, not verified
physical wiring. Revise the existing illustrative-scene caption to distinguish
measured status indicators from decorative sun/weather imagery.

Keep the combined/partial solar headline and source-specific freshness visible.
Solar cloud readings and local readings have different ages; do not present them
as a synchronized live balance. Home-network-only behavior is intentional: away
from home, battery/meter show saved/offline status while solar cloud data can
continue updating. One unavailable source must not hide healthy sources or keep
the whole Home scene loading indefinitely. Detailed values, times, errors and
refresh controls belong on Details.

Preserve reduced-motion static presentation, accessible labels that do not rely
on color/animation, small-phone and large-text readability, offline assets and
background/offscreen ticker suspension. Use the existing code-native artwork;
record licensing/performance implications if adding assets or dependencies.
Animation speed is decorative, not a calibrated wattage indicator.

Dependencies: #6 battery and #7 meter normalized readings; any displayed household
balance additionally requires #7's calculation verification. Implement battery
presentation after #6 if #7 is still pending. #19 retains existing physical/native
verification; new visual checks belong here or in an explicit follow-up at closure.
Appliance recommendations and history remain separate.

## Todo

- [ ] Produce a reviewable extension of the existing Home scene with battery percentage/state/power and grid direction/power while preserving the solar headline and Details action.
- [ ] Bind battery fill and state to #6; implement charging, discharging, idle, zero SOC, full SOC, unknown, loading, stale and off-network presentation.
- [ ] Bind grid direction and power to #7; distinguish import, export, zero net exchange and unavailable readings.
- [ ] Gate any household-use figure or combined flow claim on verified AC boundaries and timestamp alignment; do not infer solar-to-battery attribution.
- [ ] Share source controllers/caches with Details; keep loading and source failures independent and add no animation-driven requests or cooldown resets.
- [ ] Keep saved/off-network status explicit while SolarEdge/SolaX cloud readings remain usable; preserve missing-versus-zero semantics.
- [ ] Update captions/accessibility semantics so decorative motion and measured status are distinguishable without relying on color or movement.
- [ ] Preserve reduced motion, lifecycle suspension, loading bounce behavior and offline artwork; keep small-screen/large-text layouts readable.
- [ ] Add meaningful synthetic widget/state tests for direction changes, stale/error states, independent sources, reduced motion and lifecycle behavior; no shipped sample mode.
- [ ] Run required Flutter checks and focused Android visual walkthroughs with live readings, Home/Details navigation, restart and off-network recovery; record rendering cost and distinguish emulator from physical-device evidence.
- [ ] Carry uncompleted physical Android/native iOS verification into an explicit follow-up before closing; retain the existing #19/#25/#30 checks.
