# House launcher icon

The owner selected the latest green-and-ivory concept, including the front door
to the right of the projecting bay window, on 2026-09-25.
The final vector keeps the attic and both three-pane windows on one vertical
centre line. The upper and lower middle-pane dividers align, while the lower bay
is slightly wider overall. Its width is reduced slightly from the selected
concept to fit a door between the narrow concept and the first wider-door revision.

- `selected-concept.png`: selected generated concept, not the private house photo.
- `house.svg`: editable vector master, simplified from that concept for small sizes.
- `house.png`: 1024px opaque export of the installed design.
- `preview.png`: circle, rounded-square, squircle and simulated themed previews,
  plus actual 20–60px exports. This is generated artwork, not a device screenshot.

The green is the app's `#22634A` theme seed; the outline is warm ivory `#FFF2D8`.
The steep gable, attic window, upper three-part window, bay and right-hand door
remain distinct at launcher sizes. At 20px the smallest details naturally soften.

## Regenerate

From the repository root, use Python 3.9 or newer:

```sh
python3 -m venv .local/icon-venv
.local/icon-venv/bin/python -m pip install -r scripts/icon-requirements.txt
.local/icon-venv/bin/python scripts/generate_icons.py --preview app/assets/icon/preview.png
git diff --check
```

The pinned renderer uses a prebuilt wheel where available; installing from source
also requires Rust/Cargo. The generator runs offline once dependencies are installed.
There is no Flutter runtime dependency on these tools or the source artwork.

Edit the SVG's background rectangle and stroked paths, then regenerate. Keep its
108×108 viewport, the background rectangle and the single group of paths. Paths
use explicit stroke widths and inherit the group's color and round caps/joins;
convert other SVG shapes or transforms to paths before using them here.

Android output is in `app/android/app/src/main/res`:

- `mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`: legacy 48–192px icons.
- `drawable/ic_launcher_foreground.xml`: 108dp vector foreground.
- `values/ic_launcher_colors.xml`: solid background color.
- `mipmap-anydpi-v26/ic_launcher.xml`: adaptive foreground/background.
- `drawable/ic_launcher_monochrome.xml` and `mipmap-anydpi-v33/ic_launcher.xml`:
  a transparent monochrome outline for supported themed launchers.

The existing manifest's `@mipmap/ic_launcher` selects the right version. Android
applies its launcher mask; the layers contain no baked-in mask or shadow. The
preview command checks that all foreground pixels fit the central 66dp safe circle
and previews the visible central 72dp. See the
[Android adaptive-icon guidance](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive).

iOS output replaces every PNG referenced by
`app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`, including the
1024px marketing icon. Exports are RGB without an alpha channel and have square
edges, leaving corner masking to iOS. Legacy Android and iOS use the central
72dp crop so the house has the same apparent size as the adaptive icon.

## Device check

Run the normal Flutter formatting, analysis and unit/widget checks in `app/`,
then `flutter build apk --debug`. Update an existing emulator with
`adb -s DEVICE_ID install -r app/build/app/outputs/flutter-apk/app-debug.apk`
from the repository root. The `-r` flag retains app data. Do not uninstall, clear
app data, or wipe the emulator. Inspect the launcher app drawer and home screen;
enable themed icons on a supporting launcher to check its monochrome rendering.

Verified on 2026-09-25: the final debug APK replaced the installed app on the
existing API 36 emulator, with saved preferences byte-for-byte unchanged. A
local native instrumentation check loaded the installed application icon,
confirmed its adaptive and monochrome layers, and rendered both for visual
inspection. Direct app-drawer/home-screen observation was unavailable because
the computer UI tool could not attach to the emulator.

Full Xcode is not installed on the development Mac, so iOS simulator/device
appearance is deferred until Xcode and an iOS simulator or signed device are
available. Generated asset dimensions and opacity can be checked on any platform.
Physical Android launcher checks also remain a follow-up.
