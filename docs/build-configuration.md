# Build configuration

The Flutter SDK version and checks are pinned in
[the CI workflow](../.github/workflows/checks.yml). `app/pubspec.yaml` keeps this
private app unpublished with `publish_to: 'none'` and supplies the app version
and build number. Flutter build-name/build-number flags can override those values;
Android reads them as versionName/versionCode and iOS as
CFBundleShortVersionString/CFBundleVersion.

## Android

The Flutter Gradle plugin follows the Android application plugin in
`app/android/app/build.gradle.kts`. The existing template compatibility flags
`android.newDsl=false` and `android.builtInKotlin=false` remain in
`app/android/gradle.properties`. SDK values still come from Flutter. Split APK
version codes may include Flutter's ABI offset; the existing
`force-version-code-ignoring-abi` Gradle property controls that behavior.

Release builds currently use the debug signing configuration so local
`flutter run --release` works. Distribution needs its own signing setup; this
cleanup does not make the app ready for store publication.

The main manifest retains internet permission, the Flutter embedding version 2
metadata used for plugin registration, and the `PROCESS_TEXT` query used by
Flutter's text-processing plugin. Debug/profile manifests retain development
network permission. The launch theme supplies the initial splash background;
`NormalTheme` supplies the window background during Flutter initialization and
behind its UI. Day/night resources preserve the existing platform appearance.
Local HTTP and backup restrictions remain unchanged; see [P1](p1-check.md).

## Browser preview

`app/web/index.html` retains `$FLUTTER_BASE_HREF`, substituted by Flutter's
`--base-href` build option. A deployment subpath starts and ends with `/`.
`flutter_bootstrap.js` remains the loader. The preview opens without device
credential storage or live provider requests; it is not live integration testing.

## Tool-owned and executable documentation

Keep generated launcher XML markers and edit the SVG/generator instead of exported
assets. Xcode project/storyboard annotations, Flutter metadata, lockfiles and
other generated/third-party outputs are outside source-comment cleanup. Preserve
preprocessor includes/imports, shebangs and analyzer directives, including the
scene benchmark's `avoid_print` suppression.

The module docstrings in `scripts/check_solaredge.py` and
`scripts/generate_icons.py` supply `argparse` help via `__doc__`. They are executable
CLI content and remain intact so comment cleanup does not change `--help` output.
