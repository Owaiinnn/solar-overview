## Purpose

Extend the existing animated house so the owner can see battery charge/status and
grid import/export at a glance alongside the two solar sources.

## Description

Owner-requested follow-up on 2026-10-04 to the merged Home scene in #28 / PR #33.
Reuse the green/ivory visual identity, roof panels, sun, loading bounce and
Home-to-Details navigation. The updated shared house artwork is tracked in #38. Do not reopen #28 or the superseded bolt ticket #11.
The original scene accepted only solar production/loading state. P1 and battery
Settings/Details are now implemented in merged #7 and #6; physical/native
follow-ups remain in #42 and #53. Household calculation is tracked in #43.
The Home implementation and verification recorded below extend those controllers.

House-reference update (2026-10-04): use #38's corrected front elevation from the
new normal/ultrawide photographs. Account for camera offset, tilt and lens distortion;
do not reproduce skewed walls or windows. Keep the tall hedge immediately beside
the door in the animated scene, matching the revised logo, and exclude all other
plants/garden details. Keep real bay-left/door-right asymmetry. Source photos stay
private; the geometry is recreated as editable artwork. Energy indicators must
remain readable without obscuring the door, hedge or key windows.

There are only two solar sources: SolarEdge and SolaX. The inverter card in the
INDEVOLT app repeats the existing SolarEdge system. Add the separate battery and
P1 grid meter to the presentation, never a third solar source or a battery-derived
solar total. Use the normalized, independently cached sources from #6/#7; the
scene must not query APIs, create a refresh loop or change cloud cooldowns.

Show a battery shape beside the existing house and an indicator driven by valid
SOC. Following the owner refinement on 2026-10-15, keep percentage, readable
Charging / Discharging / Idle / Unavailable status and verified power on Details. Animate movement into the
battery during eligible charging and out during eligible discharge; idle is still.
SOC must not determine the operating state: a high/low percentage is not proof of
charging/discharging. Keep a last-known percentage visibly qualified when stale,
and stop directional movement on stale, offline, unknown or inconsistent data.

Add a compact grid illustration; keep Importing / Exporting / No net exchange
and verified W/kW on Details. Animate grid-to-house or house-to-grid direction only when the
meter source is eligible; zero is distinct from unavailable. Show household use
only when #43's measurement coverage, AC boundaries and timestamp alignment are
satisfied. Otherwise omit the number or explain unavailable consumption without
blocking independent battery/grid readings. Do not imply the battery is charging
from solar specifically: grid charging is possible and source attribution is not
established by direction alone. The illustration remains schematic, not verified
physical wiring. Use scene information and accessible labels to distinguish reported status
indicators from decorative sun/weather imagery.

Keep the combined/partial solar headline and source-specific freshness visible.
Solar cloud readings and local readings have different ages; do not present them
as a synchronized live balance. Home-network-only behavior is intentional: away
from home, Details shows saved/offline battery/meter status while solar cloud data can
continue updating. One unavailable source must not hide healthy sources or keep
the whole Home scene loading indefinitely. Detailed values, times, errors and
refresh controls belong on Details.

Preserve reduced-motion static presentation, accessible labels that do not rely
on color/animation, small-phone and large-text readability, offline assets and
background/offscreen ticker suspension. Use the existing code-native artwork;
record licensing/performance implications if adding assets or dependencies.
Animation speed is decorative, not a calibrated wattage indicator.

Dependencies: #38 shared house artwork, #6 battery and #7 meter normalized readings; any displayed household
balance additionally requires #43's calculation verification. Independent grid
presentation can use the merged #7; battery presentation requires #6. #19 retains existing physical/native
verification; new visual checks belong here or in an explicit follow-up at closure.
Appliance recommendations and history remain separate.

Scope refinement (2026-10-05): compose independent states on one shared house,
rather than building a different house asset for every combination. #46 owns the
dark zero-production theme, stars and warm windows; this issue owns battery/grid
layers and their combinations. Keep scene state resolution outside the painter,
with typed inputs that distinguish valid zero, unknown, stale and loading. A dark
house does not mean all energy activity has stopped.

Minimum review/test combinations (synthetic fixtures only):

| Solar presentation | Battery status | P1 grid status | Expected scene |
| --- | --- | --- | --- |
| Eligible positive | Charging | Exporting | Day house, charging battery and export direction |
| Complete eligible zero | Charging | Importing | Dark house from #46 with both activity indicators |
| Complete eligible zero | Discharging | Exporting | Dark house with discharge and export indicators |
| Complete eligible zero | Idle | No net exchange | Dark house with ambient motion only |
| Eligible positive | Unavailable | Importing | Solar and grid remain visible; battery unavailable |
| Unavailable or partial zero | Charging | Importing | No false whole-system zero theme; valid local activity remains |

These are independently observed statuses, not proof of a specific source-to-load
path. Grid import plus battery charging does not, by itself, quantify how much grid
power reaches the battery; grid export can occur with zero solar because a battery
may discharge. Preserve all existing unavailable-data and source-attribution guards.
Compose reduced motion and loading consistently with #46. Do not require every
cross-product state to have a separate painter or image.

Owner follow-up (2026-10-13): keep the sunny production scene consistent with
#46's spacious sky, lower shared house, full-screen palette and matching controls.
Treat this as the producing variant of the same composition. Preserve the loading
bounce independently; charging here means battery charging only when measured.
At the time of that request, the daytime illustration still used its earlier
compact composition. The implementation below now aligns the day and dark layouts.

Cover the complete cross-product through composed layers and parameterized tests:

| Layer | States to combine independently |
| --- | --- |
| Solar/theme | Eligible positive (complete or partial), complete eligible zero, partial zero, unavailable; no connections is an explicit empty state |
| Battery | Charging, discharging, idle, unavailable/unknown, not configured |
| Grid | Importing, exporting, no net exchange, unavailable, not configured |
| Data quality per source | Initial loading, refreshing with eligible data, recent saved cloud data, stale, missing, failed, storage error, inconsistent direction/power, future/skewed timestamps |
| Battery fill | Unknown, 0%, intermediate, 100%; valid SOC never substitutes for operating state |
| Motion/layout | Active, offscreen, background, reduced motion, small phone, large text |

Every valid combination receives the same house plus the eligible independent
layers. Do not create separate screens/assets for each product of these states.
Unavailable configured devices retain a readable Details status and Home semantics; unconfigured devices
can be omitted. Only the affected source stops directional motion on bad data.
Keep positive solar with grid import, zero solar with battery charging, battery
discharge with grid export, idle battery with either grid direction, and no solar
connections with valid local readings in the review gallery. Zero solar is not a
synonym for an idle home, and concurrent activity never proves an energy path.
Automate the full solar × battery × grid state matrix; then apply each data-quality
failure independently and verify reduced-motion/background invariants. No live
provider or home-network access is required for those synthetic checks.

Implementation on 2026-10-14 (agent-run; awaiting PR review/merge):

- Home shares the existing battery/P1 controllers with Details. Typed local states
  qualify each source independently; no requests, timers or cooldown changes were
  added to Home. The original house geometry and single entrance hedge remain.
- Both solar themes use the same spacious 360×420 composition. The owner requested
  refinement of the initial flat battery/pylon icons; the final code-native artwork
  uses shaded cabinets/beams, ivory/green faces, charge gauge, insulators and ground
  shadows to match the house. No asset/dependency or license change was needed.
- Readable cards show reported SOC/state/pack DC power and P1 direction/net watts.
  Cached SOC is explicitly last-known. Unknown/conflicting, stale, failed, invalid
  timing and storage-error sources stop their own arrows without hiding others.
  Known zero stays distinct from unavailable. Unconfigured local sources are omitted.
- Battery animation is a schematic of recently received reported state, never a
  claim of current measurement time. Source time remains unknown. Caption and
  accessible labels distinguish decorative imagery and independent observations;
  no household-use number, solar-to-battery attribution or AC/DC balance is shown.
- Local direction has a separate three-second controller so solar loading bounce
  cannot control local activity. Both controllers respect reduced motion, disabled
  ticker mode, navigation and lifecycle. Details stays fixed above navigation;
  content scrolls and cards stack for small screens/large text.
- Required checks passed with pinned Flutter 3.47.5: dependency resolution,
  formatter (73 files), analyzer (no issues), all 283 unit/widget tests. Tests cover
  the 150 solar × battery × grid combinations, per-source quality overrides, SOC
  unknown/0/intermediate/100%, inconsistent power, direction changes, loading,
  reduced motion/background/offscreen behavior and 360×640 at 200% text.
- Android API 36 emulator synthetic gallery passed for ten independent scenarios,
  with Home/Details navigation and offscreen suspension. Day/dark active, idle,
  unavailable and saved combinations were visually inspected. Gallery images stay
  in ignored app/build/home-preview; no test/sample mode ships in the application.
- Final Android profile run (two-second warm-up, 12 seconds per theme, both local
  directions active, no concurrent builds/tests): positive 722 frames, build p95
  0.551 ms / raster p95 2.038 ms; dark 720 frames, build p95 0.604 ms / raster p95
  2.275 ms. Neither sample had build/raster frames above 16.67 ms. Earlier samples
  overlapped build/test work and were noisier; these remain emulator samples,
  not physical-device performance claims.
- Restored the normal debug app with data-preserving installation. A real recent
  SolarEdge reading remained visible alongside saved/unreachable battery status;
  SolaX independently needed attention. The configured battery was unreachable
  and P1 was not configured on this emulator. Existing connections were preserved.
  Home/Details navigation and force-stop/reopen retained the last-known SOC,
  saved cloud power and battery retry deadline (238 seconds before restart,
  177 seconds afterward), without resetting waits. An initial UI capture hit the
  splash screen; only the subsequent fresh UI dump is counted as restart evidence.
  No emulator network settings were changed; Wi-Fi/mobile data remained enabled.
- Fresh battery/P1 Home readings and off-network/return-home recovery could not
  be checked with these connections. Those live emulator checks are explicitly
  transferred to open #19, alongside physical Android/native iOS. Synthetic
  combinations and historical #6/#7 evidence do not substitute for this check.
- Physical Android and native iOS scene verification is explicitly carried into
  open #19; #25/#30/#42/#53 remain open for their existing provider/device checks.
  Only an emulator is connected; full Xcode is unavailable. These are deferred
  checks, not results claimed from synthetic or emulator evidence.

Owner refinement on 2026-10-15 (supersedes the Home status cards above):

- Removed numeric battery/grid cards from Home; battery percentage, reported power
  and state remain on Details. Raised the scene minimum height from 300 to 420 so
  the artwork has more space. Solar headline/source badges and fixed Details action
  remain. Screen-reader scene labels retain independently qualified local statuses.
- Redrew the battery from the supplied enclosure reference: wide front, narrow
  left indicator strip, shaded right edge and connectors. Kept green/ivory colors;
  no reference photo, original branding or product text is bundled. Missing SOC
  remains distinct from an empty indicator; saved/conflicting sources stay still.
- Replaced sun spokes and travelling panel rays with a shaded amber disc and soft
  breathing halo. Muted unavailable/partial-zero colors, loading bounce, reduced
  motion and the existing night stars/shooting-star paths remain intact.
- All five Details cards now have accessible tappable info buttons. Measurement
  caveats, source definitions and refresh policies open in scrollable dialogs.
  Readings, current/saved/stale qualifications, errors and refresh controls remain
  visible; timestamps and secondary values move into collapsed measurement details.
  Home's longer scene explanation uses the same info control beside View details.
- Agent-run Flutter 3.47.5 checks passed: dependency resolution, formatting (77
  files), analyzer with no issues, all 284 unit/widget tests. Coverage includes
  all card dialogs at 360×640 with 200% text, saved readings, no Home percentage,
  larger scene constraints and the existing full state/motion matrix.
- Android API 36 synthetic ten-scenario Home gallery and compact Details walkthrough
  passed. Visually inspected day/night composition, the final shaded sun, battery,
  compact source cards and their info dialogs. Screenshots remain ignored under
  app/build; no sample readings or preview switch ships in the normal app.
- Final profile sample on this Android emulator: day 717 frames, build p95 0.652 ms,
  raster p95 19.627 ms, 289 frames over 16.67 ms; dark 717 frames, build p95
  0.930 ms, raster p95 18.256 ms, 184 frames over 16.67 ms. Both execution tests
  passed. The emulator log identifies llvmpipe software Vulkan; these slower
  raster results do not repeat the earlier accelerated sample and are not a
  physical-device smoothness claim. Physical rendering verification remains #19.
- Rebuilt and restored the normal debug application with `adb install -r`,
  preserving saved connections and leaving synthetic fixtures out of the app.
- Live battery/P1 recovery and physical Android/native iOS remain deferred to open
  #19 as already recorded; these layout checks do not claim new provider evidence.

## Todo

- [x] Reuse #38's corrected house geometry and retain only the tall hedge beside the door; check consistency with the revised logo and avoid photographic perspective distortion.
- [x] Produce a reviewable extension of the existing Home scene with independent battery/grid artwork and their percentage/state/power readings on Details, preserving the solar headline and Details action.
- [x] Bind battery fill and state to #6; implement charging, discharging, idle, zero SOC, full SOC, unknown, loading, stale and off-network presentation.
- [x] Bind grid direction and power to #7; distinguish import, export, zero net exchange and unavailable readings.
- [x] Gate any household-use figure or combined flow claim on verified AC boundaries and timestamp alignment; do not infer solar-to-battery attribution.
- [x] Share source controllers/caches with Details; keep loading and source failures independent and add no animation-driven requests or cooldown resets.
- [x] Keep saved/off-network status explicit on Details and in Home semantics while SolarEdge/SolaX cloud readings remain usable; preserve missing-versus-zero semantics.
- [x] Update scene information/accessibility semantics so decorative motion and measured status are distinguishable without relying on color or movement.
- [x] Preserve reduced motion, lifecycle suspension, loading bounce behavior and offline artwork; keep small-screen/large-text layouts readable.
- [x] Add meaningful synthetic widget/state tests for direction changes, stale/error states, independent sources, reduced motion and lifecycle behavior; no shipped sample mode.
- [ ] Run required Flutter checks and focused Android visual walkthroughs with live readings, Home/Details navigation, restart and off-network recovery; record rendering cost and distinguish emulator from physical-device evidence. Available checks passed as recorded above; the unavailable live battery/P1 and off-network recovery portion is transferred to #19.
- [x] Carry uncompleted physical Android/native iOS verification into an explicit follow-up before closing; retain the existing #19/#25/#30 checks.
- [x] Compose independent solar/theme, battery and grid state on one shared house; review the scenario matrix with #46 and test valid simultaneous activity, partial data and independent failures.

- [x] Align the sunny scene composition with the expanded zero-production scene while preserving shared artwork and independent loading behavior.
- [x] Exercise every solar × battery × grid state combination and independent data-quality overrides, including empty sources and SOC boundaries.
- [x] Apply the 2026-10-15 refinement: enlarged Home animation without percentage cards, reference-shaped battery, softer sun without panel rays, and compact Details cards with tappable explanations.
