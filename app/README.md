# Solar overview mobile app

Android and iOS starter app with SolarEdge connection settings. Enter a site ID
and API key in **Settings → SolarEdge → Test & save connection**. The app validates
them with SolarEdge before saving one credential record in protected device
storage. On later launches it reads that record automatically. Replacement and
removal are available from the same screen.

No real key is bundled, prefilled, or loaded from `.env` files. The app opens on
Overview, which shows returned production and today's energy after connecting.
Without a connection it offers a link to Settings. There is no sample mode.
Appliances and History have navigation and clear coming-later screens; their
features belong to tickets #8 and #5. SolaX panels/inverter (#21), the separate
PowerFlex battery (#6), and household-meter sources (#7) are not connected yet.
SolaX API access has been verified outside the app; see
the [API findings](../docs/solax-check.md). Overview and History will be extended
through #4/#5; battery integration is deferred.

## Run locally

### Browser preview in VS Code

Open the **repository root** (`solar-overview`, the folder above `app`) in VS Code.
Install the recommended Flutter extension, open **Run and Debug**, select
**Solar overview — Browser preview**, and press **F5** (or click the green play
button). The configuration opens Chrome at a local URL with an available port.

The browser target shows the same navigation and empty states without readings.
It has no API-key entry, credential persistence, or live SolarEdge requests. Use it
to develop the UI; test the real connection and protected storage on a mobile target.

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

The Android and iOS launcher icons use the owner's house-outline design.
See [icon assets and regeneration](assets/icon/README.md) for the editable master,
selected concept, platform exports and device-verification instructions.

- `lib/main.dart`: starts Flutter and opens the saved connection.
- `lib/src/app.dart`: the screens, composed from Flutter widgets (UI building blocks).
- `lib/src/connection_controller.dart`: coordinates loading, testing, saving, refresh, and removal.
- `lib/src/credential_store.dart`: stores one credential record using `flutter_secure_storage`.
- `lib/src/solaredge.dart`: requests overview/site details and normalizes W and Wh readings.
- `lib/src/site_time.dart`: resolves site timestamps and handles daylight-saving ambiguity.
- `lib/src/reading_store.dart`: securely persists the last successful snapshot and refresh deadline.

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

## Refresh, saved readings, and freshness

One controller serves every screen. Startup fetches when the saved refresh wait
has expired; otherwise it restores the last successful reading. Manual refresh,
connection tests, and replacements share a **15-minute device-local interval**,
reserved in secure storage before the request. Failed requests use the same wait.
There is no background API polling. Refresh eligibility and reading freshness
update on screen each minute and when the app resumes.

Each successful attempt makes two sequential HTTPS calls: `overview`, followed by
`details` for `location.timeZone`. The monitoring API's published limits are 300
requests per account token daily, a parallel daily limit per site/source IP, and
three concurrent calls per source IP. A 15-minute interval permits 96 attempts
(192 requests) per 24 hours on one device. See the official
[monitoring API reference](https://knowledge-center.solaredge.com/sites/kc/files/se_monitoring_api.pdf),
“Usage Limitations” and “Site Details” (checked 2026-09-28).

**Each phone has its own cache and wait.** Other phones, apps, and scripts share
SolarEdge's quota but cannot coordinate through this local cache. Two frequently
refreshed phones can exceed the account quota. HTTP 429 pauses this phone's
requests for a conservative 24 hours; the pause survives restart and disconnect.
Device clock changes, cleared app data/reinstallation, and storage failures can
limit this protection. It is not a backend or account-wide quota guarantee.

Only normalized readings, site ID, timezone, fetch time, and refresh deadline
are cached, using the same native secure-storage configuration as credentials.
No raw API responses or credential-bearing URLs are saved. A failed refresh
keeps the last successful snapshot and shows an error. Replacement clears the
old snapshot before saving new credentials; a failed credential write restores
it. Disconnect removes credentials and readings while retaining the wait.
Unreadable/unwritable cache storage blocks network requests until **Retry storage**
succeeds. Removing an unreadable cache sets a conservative 24-hour pause.

Reported timestamps are resolved in the site's IANA timezone, never the phone's.
The bundled timezone database includes aliases such as `Europe/Amsterdam`.
Readings become **stale after 30 minutes**; this is the app's conservative display
threshold, not a provider freshness guarantee. Missing/invalid timestamps,
unknown zones, future readings, and ambiguous or nonexistent daylight-saving
times show **freshness unavailable**. A missing reading remains unavailable;
zero remains a valid measurement. Today's energy is shown only when the reading
belongs to today in the site's timezone, so yesterday's cached energy does not
carry over at midnight.

## Verification

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

The unit/widget tests also cover persistent refresh waits, 429 backoff, cached
offline startup, storage failures/recovery, replacement/disconnect, site timezone
conversion, DST gaps/repeated hours, midnight rollover, and freshness updates
while open or resumed without API polling. HTTP fixtures cover denied access,
redirects, rate limits, server/network/timeout failures, and malformed responses.

The unit/widget tests cover connection validation, restoration, failed
replacement/save/removal, error redaction, refresh limiting, missing values,
hidden/cleared inputs, and browser preview without readings or credential entry.
Navigation checks cover all four tabs, the Overview shortcut to Settings, form
state across tabs, a small screen with larger text, and retaining restored
readings without extra API requests when changing tabs.

When a mobile target is available, run the native storage test:

```sh
flutter test integration_test/credential_storage_test.dart -d DEVICE_ID
```

Both native tests use separate synthetic records and leave the user's connection
alone. They verify credential persistence/removal and reading-cache/refresh-wait
persistence across store instances.
The owner confirmed on the Android emulator that a live SolarEdge connection
updates both screens, credentials persist after fully closing/reopening the app,
and removing the connection works. These are user-reported manual checks, separate
from the automated native test. Physical Android phone and iOS checks are pending.
When testing those targets, save a real connection, fully close/reopen the app,
confirm readings return without reentering the key, then remove the connection
and reopen to confirm it is gone. Enter credentials only through the app settings.


Ticket #3 live follow-up: with the updated app on Android, confirm the site timezone
and a real reading appear, fully close/reopen within 15 minutes to see the saved
reading and remaining wait, then retry after the wait. Repeat offline after the
wait to confirm the saved reading remains with a connection error. Check that
readings age to stale after 30 minutes. These new live checks are pending in
[#19](https://github.com/Owaiinnn/solar-overview/issues/19); automated failure and
native-storage checks use synthetic data. Ticket #3’s implementation is merged
and its issue is closed. Keep keys in mobile Settings.
