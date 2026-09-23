# Solar overview mobile app

Android and iOS starter app with SolarEdge connection settings. Enter a site ID
and API key in **Settings → SolarEdge → Test & save connection**. The app validates
them with SolarEdge before saving one credential record in protected device
storage. On later launches it reads that record automatically. Replacement and
removal are available from the same screen.

No real key is bundled, prefilled, or loaded from `.env` files. The Overview can
show the returned production and today's energy, or explicitly labelled sample
data. The PowerFlex and household-meter sources are not connected yet.

## Run locally

### Browser preview in VS Code

Open the **repository root** (`solar-overview`, the folder above `app`) in VS Code.
Install the recommended Flutter extension, open **Run and Debug**, select
**Solar overview — Browser preview**, and press **F5** (or click the green play
button). The configuration opens Chrome at a local URL with an available port.

The browser target uses sample data automatically. It has no API-key entry,
credential persistence, or live SolarEdge requests. Use it to develop the UI;
test the real connection and protected storage on a mobile target.

For a terminal development server that you open in any browser:

```sh
cd app # From the repository root; skip if already in app.
export PATH="/Users/owain/.local/share/flutter/bin:$PATH"
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

Open the printed local URL. Press `r` to hot reload, `R` to hot restart, and `q`
to stop. For richer debugging, use the VS Code Chrome configuration above.
If port 8080 is in use, stop the earlier preview or choose a different port.

Flutter/Dart extensions and the SDK path are configured locally on the development
Mac. The machine-specific `.vscode/settings.json` is Git-ignored; on another
machine, select your Flutter SDK through VS Code when prompted.

### Android / iPhone

Flutter 3.47.5 / Dart 3.13.4 was used for this change. On this Mac, Flutter is
installed at `/Users/owain/.local/share/flutter`. From this `app` directory:

```sh
export PATH="/Users/owain/.local/share/flutter/bin:$PATH"
flutter pub get
flutter doctor
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with an Android or iOS device/simulator ID from `flutter devices`.
On another computer, install Flutter and use that installation's `bin` directory.
Once running, pressing `r` in the terminal applies most code changes with hot reload.

Android is the current development priority. As of 2026-09-23, Android Studio,
the Android SDK and CocoaPods are installed on the owner's Mac. The Android debug
build, API 36 emulator launch and native storage integration test have passed.
Full Xcode is not installed, so iOS builds/storage verification remain deferred.
Real Android phone testing is still pending. For a fresh machine, follow the
relevant official setup:

- [Android setup](https://docs.flutter.dev/platform-integration/android/setup)
- [iOS setup](https://docs.flutter.dev/platform-integration/ios/setup)

Use `flutter doctor` to check remaining prerequisites. Device signing and store
distribution are not configured; generated Android release signing is still the
development default. The bundle IDs are provisional.

## What the code does

- `lib/main.dart`: starts Flutter and opens the saved connection.
- `lib/src/app.dart`: the screens, composed from Flutter widgets (UI building blocks).
- `lib/src/connection_controller.dart`: coordinates loading, testing, saving, sample mode, and removal.
- `lib/src/credential_store.dart`: stores one credential record using `flutter_secure_storage`.
- `lib/src/solaredge.dart`: makes a read-only HTTPS request and parses the overview.

The controller exposes state to the widgets using `ChangeNotifier`, so the screen
updates when a request finishes. Tests substitute an in-memory store and fake
SolarEdge service; they never use the owner's credentials.

## Credential handling

iOS uses Keychain with `unlocked_this_device` accessibility and no iCloud sync.
The same entitlements file is configured for Debug, Profile, and Release. Android
uses the plugin's default encrypted storage; backups are disabled and shared
preferences are excluded from cloud backup and device transfer. Each phone needs
its own one-time setup. On iOS, Keychain entries may survive app reinstallation;
use **Remove connection** to explicitly delete the app's saved record.

Only `https://monitoringapi.solaredge.com` receives the key. The API requires it
in the query string, so redirects are disabled and raw HTTP errors/URLs/responses
are never logged or displayed. Do not add HTTP request logging containing URLs.
An invalid replacement key does not replace existing saved credentials. A storage
failure is reported instead of claiming a successful save/removal.

The app requests an overview at startup and when testing a connection. Manual
refresh is limited to once per five minutes within a session; there is no automatic
background polling. This is not a persistent per-account rate limiter across
phones/restarts. Cloud freshness, timezone-aware stale detection, and broader
caching remain part of ticket #3. Reported timestamps are labelled as site time.

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

The 21 unit/widget tests cover connection validation, restoration, failed
replacement/save/removal, error redaction, refresh limiting, missing values,
sample mode, hidden/cleared inputs, a small screen with larger text, and the
browser preview's sample-only behavior.

When a mobile target is available, run the native storage test:

```sh
flutter test integration_test/credential_storage_test.dart -d DEVICE_ID
```

It uses a separate synthetic test record and leaves the user's connection alone.
The owner confirmed on the Android emulator that a live SolarEdge connection
updates both screens, credentials persist after fully closing/reopening the app,
and removing the connection works. These are user-reported manual checks, separate
from the automated native test. Physical Android phone and iOS checks are pending.
When testing those targets, save a real connection, fully close/reopen the app,
confirm readings return without reentering the key, then remove the connection
and reopen to confirm it is gone. Enter credentials only through the app settings.
