## Purpose

Provide a runnable Flutter foundation for Android and iPhone that is easy to develop ticket by ticket.

## Description

Create the starter app and beginner-friendly instructions so the owner can run
and change it one ticket at a time.

Can proceed while hardware access is being investigated.

Progress — 2026-09-23:

Flutter 3.47.5 is installed locally, and the `app/` directory now contains Android
and iOS projects, Settings/Overview navigation, a SolarEdge sample mode, and CI
configuration for formatting, analysis, and tests. The app README explains the
structure and run commands.

PR #10 was merged on 2026-09-23. Android Studio, the Android SDK and CocoaPods
are installed. The Android debug build and launch on an API 36 emulator succeeded;
the native credential-storage integration test passed using synthetic data.
Full Xcode and iOS native verification remain pending. Broader sample data and
Appliances/History navigation are also still pending, so this ticket stays open.

The owner chose Android-first development. Keep the iOS target, but defer full
Xcode installation and native iOS checks rather than blocking Android tickets.
The owner confirmed live SolarEdge connection, credential persistence after
closing/reopening, and removal on the Android emulator. Physical Android phone
testing is planned but has not yet been performed.

## Todo

- [x] Install/verify Flutter and document the Android and iOS tooling requirements.
- [x] Generate Android and iOS targets and show the starter screen on an available simulator/emulator.
- [x] Record any platform build that could not be verified and the specific missing prerequisite.
- [ ] Install full Xcode and verify the app on an iPhone simulator or device.
- [ ] Add navigation for Overview, Appliances, and History.
- [ ] Add clearly labelled sample data for SolarEdge, battery solar input, battery power, and household consumption.
- [x] Document run commands and the basics of Dart, widgets, and hot reload used here.
- [x] Configure formatting, analysis, and useful automated checks in GitHub Actions.
