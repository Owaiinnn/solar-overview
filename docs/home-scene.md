# Home scene

Home shows the same `ProductionTotal` as Details: eligible solar-only AC output,
qualified source coverage and the existing freshness/timestamp guard. Source
controllers, stored readings and request waits are shared; opening either page
or playing the scene never requests readings.

## Presentation

- Two eligible, aligned readings: combined power and named source coverage.
- One eligible reading: explicitly named partial subtotal, never a whole-system total.
- Positive eligible power: warm sun and three staggered rays that reach the panels.
- Valid zero: `0.00 kW`, explicit no-production text, muted sun and no travelling rays.
  Zero does not establish nighttime; there is no inferred day/night or weather state.
- Loading: connection-opening status; an already eligible other source remains usable.
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
palette and gable/window/door motifs of this repository's house icon. No downloaded
artwork, font, raster image, remote asset, paid tool or runtime dependency is added.
The editable geometry ships as Dart source; it works offline and can be changed and
redistributed with this app without a third-party asset license. Flutter's existing
SDK licensing remains unchanged.

## Rendering and accessibility

One five-second `AnimationController` repaints a `RepaintBoundary`; it does not rebuild
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
