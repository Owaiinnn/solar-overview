## Purpose

Give valid zero solar production a calm dark-house scene with warm yellow window
light and gently twinkling stars, while keeping the same recognizable house.

## Description

Owner-requested and clarified on 2026-10-05: show this scene whenever valid solar
production is zero, including during daytime. It is a decorative no-production
theme, not a claim about actual nighttime, weather or whether the home uses power.
Actual sunset detection and weather integration are not prerequisites.

Keep #38's corrected house geometry, panels, window positions, door and tall hedge.
Reuse the existing Flutter `CustomPainter` artwork in `app/lib/src/solar_scene.dart`;
do not generate a different house image or copy the painter for each variant.
Darken the house/sky palette, illuminate the existing window panes in warm yellow,
and place stars behind the house. Use slow, low-amplitude, staggered star twinkles
and very subtle window-light variation. Avoid synchronized flashing, abrupt
brightness changes or a flicker suggesting an electrical fault. Solar rays stop.

Replace the ambiguous `producing` input with explicit production eligibility/state:
today `false` covers both valid zero and missing readings. A whole-house zero
theme requires both configured solar sources to be eligible, time-compatible and
zero; partial zero must retain its source qualification and cannot establish that
the missing source is also zero. Missing, stale, failed, skewed and loading-only
readings do not trigger the zero-production theme. Define transition precedence
with the existing loading bounce and fresh partial-positive presentation.

Compose this theme with #35's independent battery/grid layers. A zero-production
house can still import/export grid power or have a charging/discharging battery.
Window lighting is decorative and must not imply measured household consumption
or the source of battery charging. Unknown energy directions remain unavailable.

Preserve reduced-motion static stars/window glow, accessible text, offline
rendering, lifecycle suspension, Home/Details navigation and legible small-screen/
large-text layouts. No API polling belongs in the scene. Update `docs/home-scene.md`
when implemented, replacing its current valid-zero/muted-sun description.

Implementation and agent verification (2026-10-12): the existing painter now uses
an explicit positive / complete zero / partial zero / unavailable presentation
resolved by ProductionTotal. Only two eligible, time-aligned zero readings activate
the dark palette, warm existing panes and staggered stars. Geometry is shared with
the positive scene. Loading retains eligible cached state, bounces the house and
holds ambient lighting still; failed refreshes re-evaluate eligibility. Reduced
motion retains static lighting, and offscreen/background motion stops. An
accessibility label explains that the dark scene is decorative. No dependencies,
assets, API requests or production mock switches were added.

Agent-run checks: Flutter 3.47.5 dependency resolution, formatting, static analysis
and all 208 unit/widget tests passed. Added zero/partial/missing/stale/unknown-time/
future/skew/error/storage/disconnected-state checks, refresh transitions, large
text, reduced motion, semantics and lifecycle/navigation coverage. Android API 36
emulator visual integration passed for complete zero, a later twinkle frame,
zero-with-loading, positive, partial zero after failure and Home/Details navigation.
The agent inspected the generated screenshots; they remain ignored and local.

Profile-mode Android emulator measurements over 12 seconds per theme, after a
two-second warm-up: positive 719 frames, build p50/p95 0.466/0.858 ms and raster
16.551/18.258 ms; zero 714 frames, build p50/p95 0.379/0.829 ms and raster
16.568/18.278 ms. Frames exceeding 16.67 ms in either phase: positive 319, zero
310. These are emulator comparison measurements, not a physical-device FPS claim.

At the owner's request while away from home, a separately ignored local entry
point supplies synthetic zero readings in memory and displays a ZERO PREVIEW
banner. Direct ADB checks verified Details navigation and a full process restart
back to zero-production Home. It never opens secure storage or contacts a provider. The normal main
entry point remains live. At the first handoff the owner's caption removal remained uncommitted; the
subsequent visual refinement below includes it in the ticket changes.

Remaining integration checks: battery/grid Home layers do not yet exist; their
composition and scenario matrix remain explicitly tracked in open #35. This
scene takes independent solar state and makes no battery/grid/household claim.
Physical Android/native iOS visual verification remains in #19; no physical-device
or live home-network checks were performed for this ticket. The owner accepted the full-screen visual direction and requested the subsequent
star/glow refinement below; final acceptance of that refinement is pending. Keep #46 open until the implementation PR is
merged; archive only after its GitHub closure is verified.

Owner visual refinement (2026-10-12): remove the redundant “Your solar home”
header from Home, retaining the Details title/back button and other tab headings.
The owner disliked the bounded dark shape and chose a full-screen muted dark-green
Home theme with matching text and controls. Remove the scene backdrop in both
zero and producing states: stars and the house sit directly on the green screen;
the positive house/sun sit directly on ivory. Theme the source badges, Details
button, bottom navigation and native status/navigation bar icon contrast together.
Only complete eligible zero selects the dark Home theme. Details/Settings and
other tabs retain their light presentation. Preserve the existing house geometry,
loading/lifecycle/accessibility behavior and no-production eligibility rules.
Include the owner's existing caption removal so the committed layout matches the
reviewed preview. This supersedes the initial bounded-background design.

Agent verification of the refinement: dependency resolution, formatting, static
analysis and all 209 tests passed, including a new regression check for theme
updates driven by SolaX and light/dark navigation isolation. Repeated Android API
36 visual integration passed for complete zero, twinkle, loading, positive,
partial-zero, Details and Settings; the agent inspected those captures. The
refreshed local ZERO PREVIEW was also inspected through ADB, confirming a seamless
green background and light native status/navigation bar icons. Existing small
phone/large-text and reduced-motion tests passed. No home-network readings or
physical-device/native iOS checks were performed. The earlier painter profile
measurements above describe the initial implementation, not a new full-screen
performance benchmark.

Further owner refinement (2026-10-12): move all stars above the house, add a
recognizable Ursa Major motif, strengthen the twinkle and give the windows more
visible glowing light. The zero scene now reserves extra sky above the unchanged
house geometry. Seven brighter stars and faint connecting lines form the Big
Dipper; six smaller background stars also stay above the roof, including during
the loading bounce. Four/six-second staggered star cycles vary brightness, size
and rays; warm window colors and radial halos breathe over twelve seconds. Reduced
motion keeps the stars and glow static. No blur layers, image assets or new
packages are introduced.

The owner also reported white “View details” lettering briefly appearing on return
from Appliances before changing to dark text. Disable the Home button's implicit
style animation so fill and foreground change together with the page theme. The
existing navigation regression test now checks the rendered label color on the
first frame and at 16/116 ms after Appliances-to-Home navigation. Android capture
also exposed inherited text-style interpolation in the source-coverage subtitle;
that subtitle now receives its theme foreground explicitly, and the same
first-frame regression test covers it.

Agent verification of the star/glow refinement: formatting, analysis and all 209
unit/widget tests passed, including reduced motion, small-screen/large-text layout
and the initial-frame foreground checks. Android visual integration passed for
zero, a later twinkle frame, loading, positive, partial zero, Details, Settings and
Appliances-to-Home. The agent inspected the constellation placement and visibly
varying window halos. The first emulator launch disconnected; cold booting the
same AVD without its snapshot restored access and preserved app data.

A fresh profile-mode run after that cold boot measured 720 positive-theme frames:
build p50/p95 0.479/0.985 ms, raster 2.069/4.016 ms, no frames above 16.67 ms in
either phase. The taller zero scene with gradients measured 715 frames: build
0.545/1.035 ms, raster 2.229/16.346 ms, 23 frames above 16.67 ms. Each measurement
covered 12 seconds after a two-second warm-up. These are emulator observations,
not physical-device FPS guarantees or a controlled comparison to the earlier
emulator session. Native iOS/physical Android checks remain in #19.

Owner follow-up (2026-10-12): add a falling/shooting star roughly every thirty
seconds and move the house lower to allow more stars. The zero scene now uses a
360×420 design area, a lower house and ten additional background stars (23 stars
including the Big Dipper). Every star and the shooting-star path stay above the
roof, including during the loading bounce. A 1.5-second shooting-star pass starts
at 28.5 seconds, then repeats every thirty seconds of active viewing, using a
fading diagonal trail and soft head glow.

The single existing animation controller now has a sixty-second zero-scene master
cycle; modulo timing preserves the existing ambient star/window speeds. No new
timer, ticker, dependency or request is added. Offscreen/background pauses preserve
phase. Loading or a production-state change resets the cycle, and reduced motion
hides the shooting star. A widget test covers the first and next pass, hidden
intervals, pause/resume, reduced motion, loading and nonzero production.

Agent verification of the shooting-star follow-up: dependency resolution,
formatting, static analysis and all 210 unit/widget tests passed, including timing,
reduced motion, navigation, first-frame text colors and small-phone/large-text
layout. The first Android capture attempt failed with missing integration-test
plugin registration. Rerunning Flutter drive with dependency/plugin generation
restored the plugin; the complete 34-second native walkthrough passed. The agent
inspected the expanded sky, lower house and an actual timed shooting-star capture,
then rebuilt the local mock-zero preview. No additional rendering-cost benchmark
was run for this follow-up; earlier profile measurements above remain historical.
Separate APK-helper changes in the workspace were preserved untouched.

GitHub publishing remains pending: automatic approval review rejected pushing
commit 684738b and publishing its updated issue/PR text because explicit permission
to export that payload to GitHub was not established. These subsequent edits and
notes are also retained locally until publishing is explicitly approved. The
existing remote PR does not yet contain the constellation/glow refinement or this
shooting-star follow-up.

## Todo

- [x] Introduce explicit eligible-positive, eligible-zero and unavailable/partial production presentation with documented loading/transition precedence.
- [x] Reuse the corrected house geometry for a dark palette, warm yellow window light and stars behind the house.
- [x] Add gentle independent star twinkling and subtle window-light variation; stop sun rays and avoid abrupt or synchronized flashing.
- [x] Trigger the dark theme for valid complete zero production regardless of time of day; retain unavailable/partial distinctions.
- [x] Compose with #35 battery/grid states without hiding valid activity or implying unverified source attribution.
- [x] Preserve static reduced motion, text semantics, lifecycle suspension and loading behavior; add no network requests.
- [x] Test positive/zero transitions, partial-zero versus complete-zero, stale/missing/skewed readings, refresh failure and reduced motion using synthetic fixtures.
- [x] Run Flutter checks and an Android visual walkthrough of dark/positive/loading states and available battery/grid combinations; record rendering cost and any deferred checks.
- [x] Remove the redundant Home header while preserving Details navigation and other tab titles.
- [x] Blend both scenes into Home: full-screen muted dark-green zero theme with coordinated readable controls, and ivory positive/partial/unavailable presentation, without backdrop shapes.
- [x] Verify the revised dark/light theme changes on either source update, Home/Details/Settings navigation, small/large-text layouts and native system-bar contrast; refresh the zero preview for owner review.
- [x] Place every star above the roof with a recognizable Big Dipper pattern, stronger smooth twinkle and brighter window halos; retain reduced motion and loading clearance.
- [x] Eliminate the transient white Details-button text on Appliances-to-Home navigation and verify the initial rendered frames.
- [x] Inspect the revised star/glow layout and navigation on Android, record rendering costs and refresh the owner's zero preview.
- [x] Lower the house, expand the overhead star field and add a brief shooting star every thirty active seconds with lifecycle/reduced-motion guards.
- [x] Verify shooting-star timing, expanded small-screen layout and actual Android rendering; refresh the local zero preview and record results.
