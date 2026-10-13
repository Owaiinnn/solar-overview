## Purpose

Restore all connection settings quickly after reinstalling development APKs,
including when away from the home network.

## Description

Owner-requested on 2026-10-13 during the ongoing Home-scene work. The owner
authorized publication and merging with #46 in PR #59. JSON setup is isolated
in its own logical implementation commit. Physical Android/native iOS follow-up
is carried forward in #19.

Implemented: first-time setup at Home → Details only when every available
controller has initialized, none is connected, and storage is healthy. Load a JSON
file or paste JSON, validate every supplied section, review source names, and save
using existing secure storage. Manual setup opens the existing Settings forms.
After saving any source, Details omits unconfigured source cards; Settings keeps
all manual forms. The existing web preview remains unchanged.

Import supports SolarEdge site/key, SolaX EU client/secret plus plant/inverter/
timezone selection, P1 IP and battery IP, with optional source sections. Save
works offline and preserves request cooldowns; it does not invent readings or
assert that credentials were tested. Normal refresh validates connections later.
Per-source save failures retain successful saves and report each outcome. Existing
connections cannot be overwritten. See [connection setup](../connection-setup.md)
for the schema, plugin choice and native-test procedure.

Agent verification (2026-10-13): `flutter pub get`, formatting, `flutter analyze`
and all 219 unit/widget tests passed. Android native checks passed for all four
secure stores using isolated keys and for actual file selection from Downloads,
review, save and configured Details. Inspected screenshots of empty setup,
review and Details. Initial test failures were scrolling/old empty-state
expectations; they were corrected, including resetting setup scroll on review.
Only synthetic data was imported; real connection keys were preserved. iOS and
physical-phone checks have not been run. Screenshots and JSON fixtures stay out
of version control.

## Todo

- [x] Show JSON/file/manual setup only for an initialized, empty installation; preserve storage recovery.
- [x] Validate version, all source fields and size before any saves, with redacted errors.
- [x] Restore supported connections offline through their controllers and existing protected stores; retain cooldowns and never import readings/tokens.
- [x] Preserve successful saves on a partial failure and expose manual recovery without replacing existing connections.
- [x] Show only configured source cards in mobile Details, with existing management forms in Settings.
- [x] Include a copyable placeholder template and developer schema documentation.
- [x] Test parsing, offline/no-network persistence, cooldowns, restart, rejection of replacements, partial storage failure, paste/file/cancel/manual flows and large text.
- [x] Verify all four native secure stores and the actual Android file picker using synthetic data and isolated storage keys.
- [x] Carry native iOS file selection and physical-device layout verification into open follow-up #19.
- [ ] Publish the issue/PR updates and pass remote CI before merging.
