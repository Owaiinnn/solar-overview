## Purpose

Refine the house logo and shared house artwork from the owner's clearer reference
photos so the launcher icon and animated Home scene resemble the actual house.

## Description

New design revision requested on 2026-10-04 after completed logo #15 and solar
Home scene #28. The owner supplied normal and ultrawide photos of the same front
facade. Keep those photos private/local; do not upload them to GitHub or commit
them. This ticket owns the revised house geometry, launcher exports and matching
house artwork in the current animation. #35 owns battery/grid status and energy
movement; use this revised artwork there rather than redesigning the house twice.
The artwork revision can proceed independently of the device integrations #6/#7.

Correct the photographs' camera offset, tilt, perspective convergence and
ultrawide distortion. The result must be a clean, level front elevation, not a
trace of the skewed photo. Use the normal view primarily for proportions and the
ultrawide to inspect details. Verticals should be vertical, window sills/fascias
horizontal and paired gable slopes visually balanced. Preserve genuine structural
asymmetry: the projecting bay is on the left and the entrance on the right. Do not
force bay/door positions into false symmetry or preserve the old artificial
window alignment if the new references show a different architectural relation.

Retain the recognizable features in simplified, readable form:

- Tall, steep triangular front gable with dark roof edging and small ridge cap.
- Narrow vertical attic window high in the gable.
- Wide upper window with a broad central pane and narrow side panes.
- Projecting ground-floor bay on the left with its broad centre, narrower side
  glazing, light frame/sill and dark flat canopy/fascia above it.
- Dark front door to the right, including its vertical glazed panels and narrow
  adjacent glazing where readable; preserve the entrance step/threshold.
- Dark horizontal trim/canopy lines separating the upper facade and ground floor.
- The single tall hedge/plant between the bay and front door, immediately beside
  the entrance. This is explicitly required in BOTH the logo and animated house.
  Keep its narrow upright silhouette and placement; simplify individual leaves.

Exclude every other plant, shrub, tree, lawn, flowerbed and garden detail. The
composition is the house and its architectural features plus that one hedge.
Exclude neighboring buildings, vehicles, house number, photographic background,
shadows/reflections from the photo and incidental street/path clutter. The
existing schematic solar roof/panels, sun and later energy indicators can remain
in the animation, but are not evidence of photographed wiring/panel placement.

Keep the established green/ivory identity and editable code-native assets:
`app/assets/icon/house.svg`, the icon-generation pipeline and
`app/lib/src/solar_scene.dart`. Use a simple high-contrast outline for the icon;
small facade details may be simplified to preserve readability. Represent the
hedge so it remains distinguishable in monochrome and small-size versions. The
larger animated house may carry more architectural detail while sharing the same
corrected front geometry and hedge placement. Avoid adding a bitmap dependency
for artwork already supported by SVG/Flutter drawing.

Update the logo-derived README banner's house drawing as well so the repository
identity does not retain the previous facade; preserve its existing text/layout.
Update design/regeneration documentation only where behavior or assets change.
Preserve existing sun-ray and loading-bounce behavior, reduced motion, lifecycle
suspension, source state and all stored connections. The hedge should stay attached
to the house composition during its loading motion, not drift independently.

Dependencies: existing #15/#28 assets and generation workflow. Coordinate the
shared art with #35; do not reopen the completed tickets. Show the revised icon
and house scene at useful sizes before finalizing. Android first, with iOS asset
exports and explicit deferred native checks. No battery/API implementation here.

## Todo

- [ ] Use both private reference photos to establish corrected facade proportions, accounting for offset, tilt and ultrawide distortion.
- [ ] Produce a level, front-facing revision with straight verticals/horizontals, a balanced gable and the real bay-left/door-right layout.
- [ ] Preserve the attic/upper/bay windows, roof edging, canopy/trim and entrance features at a level of detail appropriate to each output.
- [ ] Include ONLY the tall hedge beside the door in both logo and animated house; omit all other vegetation, house number, neighbors and photo background.
- [ ] Update the editable SVG master and matching Flutter house geometry consistently, then update the banner's house drawing without changing its text/layout.
- [ ] Produce reviewable icon/mask/small-size and Home scene previews; check the hedge, windows and entrance remain distinguishable.
- [ ] Regenerate Android legacy/adaptive/monochrome icons and iOS catalog assets with the existing reproducible workflow; verify masks, safe bounds, sizes and opacity.
- [ ] Preserve sun rays, loading bounce, reduced motion and lifecycle behavior; keep house/hedge aligned during movement and leave room for #35's energy indicators.
- [ ] Run appropriate asset-generation/content checks, required Flutter checks and Android visual verification without clearing saved connections; record uncompleted physical/native iOS checks explicitly.
- [ ] Keep source photos and private screenshots out of git and issue uploads; document the final shared geometry and regeneration steps.
