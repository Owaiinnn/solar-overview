# Home scene

Home shows the same `ProductionTotal` as Details: eligible solar-only AC output,
qualified source coverage and the existing freshness/timestamp guard. Source
controllers, stored readings and request waits are shared; opening either page
or playing the scene never requests readings. The owner confirmed the separate
solar-only AC outputs in [#4](tickets/done/04-overview.md); MPPT inputs, energy
counters and battery flows never enter this subtotal.

## Presentation

- Two eligible, aligned readings: combined power and named source coverage.
- One eligible reading: explicitly named partial subtotal, never a whole-system total.
- Positive eligible power: warm sun and three staggered rays that reach the panels.
- Valid zero: `0.00 kW`, explicit no-production text, muted sun and no travelling rays.
  Zero does not establish nighttime; there is no inferred day/night or weather state.
- Loading: `Loading…`, source-checking text and a gentle 1.5-second house bounce
  with a responsive contact shadow. An already eligible source remains visible.
  The bounce ends when opening/refresh finishes, including failures; no minimum
  wait or extra provider request is introduced.
- Stale/missing readings: unavailable or an eligible partial subtotal; per-source badges
  explain stale/unavailable status. Missing is never rendered as zero.
- Failed requests/offline/storage or authentication problems: the affected source is
  marked as needing attention and excluded. Details retains the actual error and cache.
- More than five minutes of timestamp skew: the total is withheld with an explanation.

A low-amplitude sun halo continues in quiet states. The caption explicitly describes
an illustration; it is neither measured energy flow nor live weather. No battery,
household flow, wiring topology, irradiance or API update rate is implied.

## Asset and runtime choice

Evaluated on 2026-10-02, before choosing custom drawing:

- Jeffrey Christopher's [Solar Powered House](https://lottiefiles.com/free-animation/solar-powered-house-0JlvGde4Vj)
  is a seamless day/night cycle (72.8 KB JSON listed). That cycle would suggest an
  unsupported environmental state and require editing/state control.
- Just Another Guy's [Solar Panel](https://lottiefiles.com/free-animation/solar-panel-YDtMADGxnj)
  includes battery charging, which is outside the verified solar scope.
- Tanjil Mahmud's [Windmills House With Solar Panel](https://lottiefiles.com/free-animation/windmills-house-with-solar-panel-BoSa5EUHSF)
  includes wind generation absent from this installation.

These asset pages identify the [Lottie Simple License](https://lottiefiles.com/page/license):
modification and redistribution are permitted under the same license terms; creator
attribution is encouraged. Separately, the Flutter [lottie runtime license](https://pub.dev/packages/lottie/license)
is MIT, requiring its copyright and permission notice in distributed copies.
Asset licensing and library licensing are independent. None of these third-party
assets or the Lottie library is included, so no new third-party notices are needed.

The selected scene is original Flutter `CustomPainter` artwork, with the green/ivory
palette and exact front-elevation coordinates of this repository's
[`house.svg`](../app/assets/icon/house.svg): steep gable, narrow attic window,
centered three-pane upper window, left projecting bay, right-hand door and the
single tall entrance hedge.
Only the side wall, roof and panels extend that front view into the scene. No downloaded
artwork, font, raster image, remote asset, paid tool or runtime dependency is added.
The editable geometry ships as Dart source; it works offline and can be changed and
redistributed with this app without a third-party asset license. Flutter's existing
SDK licensing remains unchanged.

## Shared house geometry

The normal reference guides the facade's proportions and the ultrawide view
clarifies architectural details. Camera roll/convergence and wide-angle distortion
are removed by drawing a balanced gable with level sills/fascias and vertical
frames. This is a simplified elevation, not a photogrammetric measurement.
The bay's leftward offset and entrance on the right are real asymmetry; do not
center the bay under the upper window or align their pane divisions.

Coordinates use the icon's 108×108 viewport in both SVG and Dart:

| Feature | Shared landmarks |
| --- | --- |
| Gable / ridge cap | apex (54, 23); eaves (31, 55) and (77, 55); cap y=22.5 |
| Front wall | x=33–75; base y=78 |
| Attic window | x=52.7–55.3; y=29.5–35.5 |
| Upper window | x=45–63; y=41–49.5; dividers x=48.5, 59.5 |
| Left bay | canopy x=32.5–55.5, y=58–59.5; glazing x=34.5–55, y=59.5–71.5 |
| Bay panes / sill | dividers x=39, 50.5; sill y=72 |
| Right entrance | surround x=63.5–73, y=61–73; door x=65–71.5 to y=77.5; step y=78 |
| Single hedge | same quadratic path in SVG/Dart; narrow crown near (58.7, 54), base near y=79 |

The icon uses a closed scalloped outline so the hedge survives monochrome output.
The scene fills the same silhouette and adds sparse foliage marks, door glazing
crossbars and a handle at its larger display size. All house parts, including the
hedge, are drawn inside the same loading translation. The old flanking garden
plants and lawn-shaped oval are removed; only the abstract backdrop and animated
contact shadow remain. Open space around the house is available for future energy
indicators. Roof/panels remain schematic and do not establish real placement.

When editing geometry, update `house.svg`, the matching drawing in
`solar_scene.dart`, and the banner's existing house group together. Preserve the
banner's text and transform. Run the [icon export workflow](../app/assets/icon/README.md#regenerate)
and inspect both the mask/small-size sheet and native Home loading captures below.

## Rendering and accessibility

One `AnimationController` (five seconds normally, 1.5 seconds while loading) repaints a `RepaintBoundary`; it does not rebuild
or lay out Home on each frame. The scene uses simple paths, lines and translucent
circles without image decoding, blur filters or saveLayer effects. The static house
is repainted with the small scene each frame rather than adding a separate cache or
animation framework. Home performs intrinsic sizing on layout to give the scene the
remaining space; at larger text sizes the whole page scrolls without shrinking text.

The controller stops in Details, another tab, a disabled `TickerMode`, or any
non-resumed app lifecycle state. Disabled-animation and accessible-navigation
preferences produce a static scene and reset its phase. Resuming restores the loop.
Artwork is excluded from semantics; readable labels carry every production and
source state, independently of color or motion.

`integration_test/home_scene_test.dart` measures steady-state build/raster times for
12 seconds after a two-second warm-up. It draws only the scene with synthetic test
state, never opens secure storage, and never contacts a provider. Run it in profile
mode on Android using:

```sh
cd app
flutter drive --profile --keep-app-running -d DEVICE_ID --driver integration_test/scene_driver.dart --target integration_test/home_scene_test.dart
```

Always retain `--keep-app-running`: Flutter drive otherwise uninstalls the app
after testing and removes its saved data, even when the test itself never accesses
storage. Afterwards rebuild the normal `lib/main.dart` app and install with
`adb install -r` to preserve connections. Prefer a disposable test emulator.

Emulator numbers are a local comparison, not physical-device FPS
claims. Actual execution results and deferred checks belong in the ticket.

## Loading visual check

The Android-only `integration_test/home_loading_test.dart` holds an in-memory
connection open, captures two loading frames and completes to an empty state.
It never reads or writes real credentials or calls either provider. Run:

```sh
cd app
flutter drive --keep-app-running -d DEVICE_ID --driver integration_test/home_visual_driver.dart --target integration_test/home_loading_test.dart
```

Synthetic screenshots are saved locally under ignored `app/build/home-preview/`.
As with the scene benchmark, keep the app installed, then rebuild the normal
`lib/main.dart` target and install with `adb install -r`.

## Painter phase

The house rests on the ground at phase zero, including reduced-motion mode.
The contact shadow changes with the loading lift. The entrance hedge stays inside
the same house transform; the backdrop is abstract and adds no other vegetation.
Three staggered rays reach the panel surface each loop when eligible power is
positive. This timing is decorative and never represents a measured flow rate.
