# Solar Overview app

A Flutter app for Android and iOS that brings SolarEdge and SolaX production
readings into one dashboard. Development focuses on Android, with iOS support
in the codebase. See the [project overview](../README.md) for the technology stack.

## Built features

- Independent SolarEdge and SolaX connections, with setup, replacement and removal
  in Settings and credentials stored securely on the device.
- Source cards showing power, energy, measurement time, connection status and
  saved or stale readings. SolaX details include both solar inputs, inverter
  temperature and lifetime energy.
- Combined solar power when both readings are fresh and closely aligned in time;
  partial production when only one source qualifies. Energy counters stay separate.
- Saved readings across restarts, manual refresh and persistent request waits.
  Missing readings remain unavailable rather than displaying zero.

The broader direction includes production history, battery and household
consumption monitoring, and appliance planning based on available energy.

## Connect your system

In **Settings → SolarEdge**, enter your site ID and API key, then choose
**Test & save connection**.

In **Settings → SolaX**, enter an EU developer client ID and secret, find your
plant, select the supported inverter and save the connection. The integration
supports the residential X1-Micro 2 in 1. Use a separate developer application
for each phone: sharing one can invalidate another device's token. Enable the
Information Management and Monitoring Management services.

Credentials are entered only through mobile Settings. There is no bundled key
or sample-data mode. SolaX daily energy is the device's AC counter and can differ
from the plant's daily total. See the [integration notes](../docs/solax-check.md)
for details.

## Refresh, saved readings and freshness

Each source has its own 15-minute request wait and restores saved readings when
needed. There is no background API polling. Readings become stale after 30 minutes;
combined power requires measurement times no more than five minutes apart.
Refresh waits are local to each phone, while provider quotas may be shared.

## Run locally

Install the Flutter version pinned in [CI](../.github/workflows/checks.yml) and
configure an Android emulator or mobile device. From this `app/` directory:

```sh
flutter pub get
flutter doctor
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with an ID from `flutter devices`. iOS development requires
macOS and Xcode. Press `r` for hot reload while the app is running.

For a browser UI preview, open the repository root in VS Code and select
**Solar overview — Browser preview**, or run `flutter run -d chrome` here.
The browser shows navigation and empty states; live connections and secure
credential storage require a mobile target.

## Development

App code lives in `lib/`, unit and widget tests in `test/`, and native storage
tests in `integration_test/`. Run checks from this directory:

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
flutter test integration_test -d DEVICE_ID
```

The last command requires a mobile target and uses isolated synthetic records.
See [icon assets](assets/icon/README.md) for launcher artwork and regeneration.
