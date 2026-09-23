# Set up Flutter for Android and iOS with a sample-data app

Create the starter app and beginner-friendly instructions so the owner can run
and change it one ticket at a time.

## Acceptance criteria

- [ ] Install/verify Flutter and document the Android and iOS tooling requirements.
- [ ] Generate Android and iOS targets and show the starter screen on an available simulator/emulator.
- [ ] Record any platform build that could not be verified and the specific missing prerequisite.
- [ ] Add navigation for Overview, Appliances, and History.
- [ ] Add clearly labelled sample data for SolarEdge, battery solar input, battery power, and household consumption.
- [ ] Document run commands and the basics of Dart, widgets, and hot reload used here.
- [ ] Configure formatting, analysis, and useful automated checks in GitHub Actions.

Can proceed while hardware access is being investigated.

## Progress — 2026-09-22

Flutter 3.47.5 is installed locally, and the `app/` directory now contains Android
and iOS projects, Settings/Overview navigation, a SolarEdge sample mode, and CI
configuration for formatting, analysis, and tests. The app README explains the
structure and run commands.

This ticket remains open: full Xcode, Android SDK, and CocoaPods are not installed
on the development Mac, so neither mobile build has been verified. Broader sample
data and the Appliances/History navigation in the original scope are also pending.
