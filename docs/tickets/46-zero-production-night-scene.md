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

## Todo

- [ ] Introduce explicit eligible-positive, eligible-zero and unavailable/partial production presentation with documented loading/transition precedence.
- [ ] Reuse the corrected house geometry for a dark palette, warm yellow window light and stars behind the house.
- [ ] Add gentle independent star twinkling and subtle window-light variation; stop sun rays and avoid abrupt or synchronized flashing.
- [ ] Trigger the dark theme for valid complete zero production regardless of time of day; retain unavailable/partial distinctions.
- [ ] Compose with #35 battery/grid states without hiding valid activity or implying unverified source attribution.
- [ ] Preserve static reduced motion, text semantics, lifecycle suspension and loading behavior; add no network requests.
- [ ] Test positive/zero transitions, partial-zero versus complete-zero, stale/missing/skewed readings, refresh failure and reduced motion using synthetic fixtures.
- [ ] Run Flutter checks and an Android visual walkthrough of dark/positive/loading states and available battery/grid combinations; record rendering cost and any deferred checks.
