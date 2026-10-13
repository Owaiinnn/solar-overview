# Restore connections from JSON

When no connections are saved, Home → View details offers **Load JSON file**,
**Paste JSON**, and **Manual setup**. The JSON template on that page can be copied.
Manual setup opens the existing Settings forms. Once any source is saved, Details
shows configured sources and any storage recovery state; Settings still offers
all integrations. Unconfigured source cards are hidden in mobile Details.

JSON import validates the whole document before any storage changes. Review the
source names, then choose **Save connections**. Credentials are stored in the same
device secure storage as manually entered credentials. Import works offline and
does not test credentials or populate readings. Cloud readings can be refreshed
from Details or on the next app launch. Battery/P1 resume normal foreground
refresh when eligible, and require the home network. Existing request waits remain
in force. An imported address or key is not proof of a successful connection.

Use this structure, replacing every placeholder and deleting source sections you
do not use. At least one source is required; keep `version` set to `1`. Maximum
file size is 32 KB. Unknown fields, invalid keys, public IPs, and unsupported SolaX
models/timezones are rejected with messages that do not repeat credentials.

```json
{
  "version": 1,
  "solarEdge": {
    "siteId": "YOUR_SITE_ID",
    "apiKey": "YOUR_API_KEY"
  },
  "solax": {
    "clientId": "YOUR_CLIENT_ID",
    "clientSecret": "YOUR_CLIENT_SECRET",
    "plantId": "YOUR_PLANT_ID",
    "serialNumber": "YOUR_INVERTER_SERIAL",
    "model": 28,
    "timeZone": "Europe/Amsterdam"
  },
  "p1": {"address": "YOUR_P1_IP"},
  "battery": {"address": "YOUR_BATTERY_IP"}
}
```

SolarEdge site ID must be a string of digits; its API key is 32 alphanumeric
characters. SolaX uses the existing EU application credentials and supported model
28. Its plant ID, serial number and plant timezone are needed to restore the
selection offline; use manual discovery if you do not know them. Authentication
tokens and readings are never imported. IP fields accept private IPv4 addresses
without a URL or port; the existing integrations use port 8080.

The source JSON remains a plaintext file under your control. Keep it private and
out of the repository. The app never writes an export, logs its contents, or copies
your credentials to the clipboard. The Copy template button copies placeholders
only. Pasted content is hidden by default and cleared after successful validation.

If secure storage fails for one source, successful saves are retained and the
result lists each source separately. Finish failed sources through Manual setup.
Bulk import is not offered when any connection already exists and cannot replace
an existing connection. Storage recovery takes precedence over first-time setup.

Native file selection uses Flutter's [file_selector plugin](https://pub.dev/packages/file_selector)
(BSD-3-Clause; Android and iOS supported). Android has been exercised; native iOS
verification remains outstanding. Web remains the existing non-connected preview.

For the Android native integration test, use `--keep-app-running`. The default test
covers isolated secure-storage records for all sources. The opt-in native-picker
test (`--dart-define=TEST_NATIVE_FILE_PICKER=true`) waits up to two minutes for a
person or ADB automation to select a synthetic file containing only the SolarEdge
section with site ID `123` and 32 `a` characters as its key. Do not select real
credentials in this test. Its app uses in-memory controllers; all real app storage
keys are preserved. Widget tests cover file cancellation, malformed input, paste,
manual navigation, large text, and the configured-only Details transition.
