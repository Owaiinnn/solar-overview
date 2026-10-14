# Home scene

Home shows the same `ProductionTotal` as Details: eligible solar-only AC output,
qualified source coverage and the existing freshness/timestamp guard. Source
controllers, stored readings and request waits are shared; opening either page
or playing the scene never requests readings. The owner confirmed the separate
solar-only AC outputs in [#4](tickets/done/04-overview.md); MPPT inputs, energy
counters and battery flows never enter this subtotal.

## Presentation

Home starts directly with production, without a redundant app-bar title. The
Details screen retains its title/back button; other tabs retain their headings.
Both house variants sit directly on the page without a circular or boxed backdrop.
Complete eligible zero makes Home, navigation and native system bars muted dark
green with light text and coordinated badges/buttons. Other production states use
ivory. Details and other tabs keep their light presentation. Either solar source
can update the theme; changing theme never fetches data. Theme colors change
together without an animation that could briefly reduce text contrast. The Home
Details button also disables its own implicit style animation so returning from
another tab cannot briefly show the light-theme text color on its dark-theme fill.
The source-coverage subtitle uses an explicit theme foreground for the same reason.

- Two eligible, aligned readings: combined power and named source coverage.
- One eligible reading: explicitly named partial subtotal, never a whole-system total.
- Positive eligible power: warm sun and three staggered rays that reach the panels.
- Complete eligible zero: `0.00 kW`, explicit no-production text, a dark green sky,
  warm window panes and softly staggered stars. Both sources must be eligible,
  time-compatible and zero, even during daytime. No sun or travelling rays appear.
  This decorative theme does not establish nighttime, weather or household use.
- Partial zero: keep the muted sun and the named source qualification. A missing
  second source cannot establish whole-system zero.
- Loading: `Loading…`, source-checking text and a gentle 1.5-second house bounce
  with a responsive contact shadow. An already eligible source remains visible.
  The bounce ends when opening/refresh finishes, including failures; no minimum
  wait or extra provider request is introduced. The eligible production state is
  retained while refreshing: a complete cached zero stays dark, and a partial
  positive retains the warm sun. Loading suspends rays and ambient twinkles/window
  variation while the house bounces. Loading without eligible data is unavailable,
  never zero. A failed refresh immediately re-evaluates source eligibility.
- Stale/missing readings: unavailable or an eligible partial subtotal; per-source badges
  explain stale/unavailable status. Missing is never rendered as zero.
- Failed requests/offline/storage or authentication problems: the affected source is
  marked as needing attention and excluded. Details retains the actual error and cache.
- More than five minutes of timestamp skew: the total is withheld with an explanation.

A low-amplitude sun halo continues in nonzero/unknown presentations. The zero
scene has an accessibility label explaining that window lighting and sky are
illustrative. Production and source labels remain readable independently of the
artwork. No household balance, wiring topology, irradiance or API update rate
is implied. `ProductionTotal.presentation` resolves positive, complete zero,
partial zero and unavailable before the painter receives its typed input.

Battery/grid layers use typed `HomeBatteryState` and `HomeGridState`, resolved
from the same controllers as Details. The shaded battery cabinet and pylon use
the house's green/ivory palette, side planes and contact shadows. Neither obscures
the bay, entrance or hedge. The battery inset fills only from valid SOC; a missing
level has a dash and an explicit unavailable label. A known 0% remains zero.

Battery arrows illustrate the recently received **reported** charge/discharge
state only when nonzero pack DC power agrees. Receipt eligibility is not evidence
of measurement freshness: the card explicitly says source time unknown. Idle,
unknown or conflicting state/power remains still. Charging/discharging with zero
power is withheld as inconsistent. SOC never determines operating state. Cached,
old, future-receipt, failed or storage-error readings stop arrows and retain a
qualified last-known level; no stale pack power is shown as current.

Grid arrows require the existing P1 receipt and measurement freshness policy,
including its five-second clock tolerance. Signed net watts must agree with the
typed direction. Eligible zero is labelled No net exchange with 0 W; unavailable
is never zero. Local sources have independent loading/refresh/error states.
Unconfigured local sources are omitted after initialization. A failed local read
cannot hide a healthy cloud subtotal or change the solar theme. No scene or
navigation callback requests data or resets provider waits.

The cards describe independent observations, not a synchronized household balance.
The caption distinguishes decorative sky/light from reported indicators and says
arrows do not establish wiring or the battery's charging source. No household-use
figure is displayed. Battery pack DC is never added to solar AC or grid exchange.

Day and zero scenes reserve the same taller sky above the lowered original house geometry;
it contains the seven constellation stars and sixteen background stars. All stars
remain above the highest roof edge, including while loading. Its seven connected
stars form a stylized Big Dipper, part of Ursa Major, with a few smaller background
stars. The [NASA pattern reference](https://science.nasa.gov/image-article/apod-2017-november-21-big-dipper-over-pyramid-mountain/)
guides the familiar handle/bowl arrangement; no source image or asset is included.
Placement is decorative, not a live sky map or an astronomical orientation claim.
A shooting star crosses only the sky for 1.5 seconds every thirty seconds of active
zero-scene viewing, first appearing at 28.5 seconds. It has a fading trail and soft
head glow. Six paths alternate between left and right parts of the sky, each with
a different starting point and endpoint above the roof; the sequence repeats every
three minutes. The existing controller supplies this timing: ambient lighting keeps
its four/six/twelve-second periods inside a three-minute master loop, with no new
timer or ticker. Navigation/background pauses preserve the phase. Loading or a
production-state change resets the cycle; reduced motion leaves no shooting star.
The expanded scene has a 360×420 design area and scrollable minimum height so the
sky/house stay separated on small phones and with large text.

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
plants and lawn-shaped oval are removed; only the animated contact shadow remains.
Open space beside the house contains the independent battery/grid indicators. Roof/panels remain schematic and do not establish real placement.

When editing geometry, update `house.svg`, the matching drawing in
`solar_scene.dart`, and the banner's existing house group together. Preserve the
banner's text and transform. Run the [icon export workflow](../app/assets/icon/README.md#regenerate)
and inspect both the mask/small-size sheet and native Home loading captures below.

## Rendering and accessibility

The existing `AnimationController` (five seconds for the sun, a three-minute master
cycle for the zero scene, 1.5 seconds while loading) and a separate three-second
local-direction controller repaint one `RepaintBoundary`; they do not rebuild or
lay out Home on each frame. The second controller runs only while at least one
local direction is eligible, so solar loading cannot change its speed or stop it.
One bad local source removes only its own arrows. Motion speed is decorative,
not a wattage scale. No new asset, dependency or license is introduced. The scene uses simple paths, lines and translucent
circles and radial-gradient halos without image decoding, blur filters or saveLayer
effects. The static house
is repainted with the small scene each frame rather than adding a separate cache or
animation framework. Home performs intrinsic sizing on layout to give the scene the
remaining space; content scrolls without shrinking text and the Details action
stays above navigation. Local cards stack at narrow widths or large text sizes.

Both controllers stop in Details, another tab, a disabled `TickerMode`, or any
non-resumed app lifecycle state. Disabled-animation and accessible-navigation
preferences produce a static scene and reset its phase. Resuming restores the loop.
Individual drawing elements are excluded from semantics; the complete-zero scene
adds one decorative-scene explanation. Each local card has a combined accessible
label covering level, state, power and qualification. Readable labels carry every production and
source state, independently of color or motion. Star brightness varies gently on
four/six-second cycles with different phase offsets, varying brightness,
radius and ray length. Window color and soft radial halos breathe over twelve
seconds. Reduced motion keeps the stars and warm panes visible at phase zero.

`integration_test/home_scene_test.dart` measures steady-state build/raster times for
12 seconds after a two-second warm-up for each positive and zero theme. It draws
only the scene with both synthetic local-direction layers active; it never opens secure storage or contacts a provider. Run it in profile
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
the same house transform; the background belongs to Home and adds no other vegetation.
Three staggered rays reach the panel surface each loop when eligible power is
positive. This timing is decorative and never represents a measured flow rate.

## Zero-production visual check

`integration_test/zero_scene_test.dart` uses in-memory synthetic readings to check
complete zero, a later twinkle frame, zero while refreshing, positive production,
partial zero after failure, and Home/Details/Settings navigation. It never opens real secure
storage or contacts providers. Run on Android with:

```sh
cd app
flutter drive --keep-app-running -d DEVICE_ID --driver integration_test/home_visual_driver.dart --target integration_test/zero_scene_test.dart
```

Screenshots stay in ignored `app/build/home-preview/`. The ordinary `lib/main.dart`
entry point has no mock switch. Rebuild that target to return to live readings;
keep the installed app/data when switching targets. A separately ignored local
preview entry point can keep synthetic zero visible for owner review without
changing saved connections, caches or provider waits.

The review gallery uses synthetic controllers and never opens production storage:

```sh
cd app
flutter drive --keep-app-running -d DEVICE_ID --driver integration_test/home_visual_driver.dart --target integration_test/home_energy_test.dart
```

Captures are written to ignored `app/build/home-preview/`. They cover positive,
zero, partial and empty solar with active/idle/unavailable battery and grid states,
plus saved local data. State/widget tests cover all 150 solar × battery × grid
combinations, independent quality failures, SOC limits, motion policies and large
text. Restore the normal application after running the native gallery.
