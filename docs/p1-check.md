# Local P1 grid meter

The independent P1 source reads the home-network reader on port 8080 using
`GET /rpc/P1.GetData`. The owner enabled local HTTP mode and verified access from
the Mac. Flutter live-device behavior is still awaiting home-network validation.
The app uses private literal IPv4 addresses, an eight-second request timeout,
a 64 KiB response limit and no redirects. Authentication failures explain that
Digest mode is unsupported; they never expose the response or address in errors.
No device setting is changed. There is no cloud relay, discovery scan or gas UI.

## Reading provenance

[IGEN OpenData](https://docs.solarman.ai/docs/api/opendata/#get-raw-meter-data)
documents the raw endpoint. The OBIS fields, units, timestamp suffix and framed
telegram checksum follow the [DSMR 5.0.2 P1 specification](https://www.netbeheernederland.nl/sites/default/files/2024-02/dsmr_5.0.2_p1_companion_standard.pdf).
The tested parser accepts a single full framed telegram or the vendor's
brace-wrapped/raw text form with an end marker. Full slash-to-bang telegrams
require a valid CRC16; when the API omits the original header, its original CRC
cannot be verified. Unknown layouts, invalid known fields, duplicates, missing
identity/timestamp and truncated telegrams fail without replacing good readings.
Optional absent electricity fields remain unavailable.

| Raw field | Normalized meaning |
| --- | --- |
| `0-0:1.0.0` | Measurement timestamp, never HTTP receipt time |
| `0-0:96.1.1` | Electricity meter identity, stored securely and omitted from logs/UI |
| `1-0:1.7.0` / `2.7.0` | Import/export, explicit kW converted to integer W |
| `1-0:1.8.1` / `1.8.2` | Cumulative tariff 1/2 import, kWh stored as integer Wh |
| `1-0:2.8.1` / `2.8.2` | Cumulative tariff 1/2 export, kWh stored as integer Wh |
| `1-0:21/41/61.7.0`, `22/42/62.7.0` | Optional per-phase import/export power |
| `1-0:32/52/72.7.0`, `31/51/71.7.0` | Optional phase voltage/current |

Net exchange is import minus export; both fields must exist. Positive is import,
negative export, and a measured zero is distinct from unavailable. Phase sums are
not required to equal totals because the source's sampling may differ. Tariff
numbers are not labeled low/normal without establishing the owner's contract.
No interval or daily energy is calculated from these cumulative counters.

The raw endpoint avoids associating the timestamp with a separate JSON request.
During earlier discovery, the reader's snake_case JSON used W while the vendor's
descriptive JSON example uses kW, and aggregate counters differed slightly from
raw tariff sums. The app therefore does not use JSON as a fallback or silently
combine its fields with a raw telegram. Firmware/schema and import-side device
comparisons remain live-verification work in #7.

## Time, cache and foreground refresh

The timestamp parser supports Dutch DSMR `YYMMDDhhmmssS/W` in Europe/Amsterdam:
S denotes UTC+02:00, W UTC+01:00. It validates the real date and IANA seasonal
offset, rejects spring gaps and resolves the repeated autumn hour with the suffix.
Other regional conventions need explicit support rather than guessing.

The controller's provisional policy is a 30-second foreground cadence, an
8-second request timeout, a 90-second measurement/receipt freshness window and
up to five seconds of future clock tolerance. These are application policies,
not experimentally established meter cadence or guaranteed live-flow accuracy.
Failure backoff is 1/2/4/5 minutes, capped at five; the next attempt is persisted
before network access and survives restart/removal. Manual requests use that
same gate. Solar cooldowns are independent.

A new HTTP response does not renew the measurement timestamp. Older timestamps
or changed values under an identical timestamp are rejected. Repeated identical
measurements age into stale state normally. Backgrounding stops polling and
marks the last reading saved. Restart restores saved data without claiming a
new live observation; successful foreground refresh can make it current again.
Connection replacement editing pauses automatic requests, and leaving Settings
resumes them without discarding the unsaved form input.

A changed meter identity requires an explicit test/replacement in Settings,
even if the IP address stayed the same. Decreasing tariff counters produce a
persistent reset/rollover warning for that connection, without suppressing
independent current grid power. A replacement starts a new confirmed connection.
History must use meter identity and detect discontinuities independently; the
single cached snapshot is not a history baseline.

Address, normalized reading, receipt time, reset warning and request gate form
one versioned secure-storage record (`solar_overview.p1.connection.v1`). Raw
telegrams are not stored. Failed connection tests or secure writes preserve the
last good record. Storage failures stop requests until recovered. Removing P1
clears its address and reading while retaining its retry gate.

## Household consumption and platform scope

Grid exchange is not household use. Both solar systems and the battery must be
confirmed behind this meter; battery AC/bypass boundaries and source timestamp
alignment remain unverified. `suitableForHouseholdBalance` is therefore false.
No household number, solar-to-battery attribution or appliance surplus is derived.
Battery integration remains independent in #6; #35 owns Home visualization.

Android enables local cleartext HTTP in the main manifest; the P1 client restricts
its destination and does not follow redirects. Existing solar clients keep HTTPS.
iOS declares local-network use and allows local networking through ATS. Native
iOS permission/HTTP behavior still requires full Xcode and an iOS simulator/device.
Connection screens explain that the reader's HTTP mode is unencrypted local access.

## Verification

Run the normal Flutter checks, then the native synthetic HTTP/secure-storage and
visual test on Android from `app/`:

```sh
flutter drive --keep-app-running -d DEVICE_ID --driver integration_test/p1_driver.dart --target integration_test/p1_native_test.dart
flutter build apk --debug
adb -s DEVICE_ID install -r build/app/outputs/flutter-apk/app-debug.apk
```

The native test hosts an isolated synthetic server on the emulator itself and
uses dedicated test storage keys. It never contacts a home meter or reads real
credentials. It captures setup, cached restart, import/export, offline and zero
states under ignored `app/build/p1-preview/`. Keep `--keep-app-running`, or use
`--no-uninstall` with `flutter test integration_test`, to preserve installed data.
Always restore the normal app target afterward with `install -r`.

Actual test results, remaining device comparisons and unavailable checks belong
in [the ticket](tickets/07-house-meter.md). Source fixtures belong only in tests;
there is no shipped sample-data mode.
