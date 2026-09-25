## Purpose

Give Solar Overview a recognizable phone home-screen icon based on the owner's house instead of the default Flutter icon.

## Description

Design a simple house-outline logo using the reference photo supplied in the chat on 2026-09-25. Preserve the house's distinctive steep triangular front gable, narrow vertical attic window, wide three-part upper window, and lower projecting bay window. Simplify those features so the mark remains legible at launcher-icon size.

Use the app's existing green palette with a high-contrast light house outline. Keep the design free of text, brick textures, landscaping, cars, neighboring buildings, and photographic detail. The reference photo remains local; do not upload or commit it. The owner selected the revised green-and-ivory concept with the front door on 2026-09-25. The final refinement restores the common vertical centre line through the attic and both three-pane windows. Upper and lower middle-pane dividers align. The lower window is slightly narrower than the selected concept, remains wider than the upper window, and leaves room for a bottom-right door between the narrow concept and the first wide-door revision.

Scope: the phone launcher/home-screen icon on Android and iOS, not the Overview navigation icon. Android remains the verification priority; retain iOS assets and record any deferred iOS device checks.

Implemented on 2026-09-25: editable SVG master, selected concept, 1024px export and mask/readability sheet in `app/assets/icon/`; all Android legacy/adaptive/monochrome and iOS catalog assets replaced. Regeneration instructions are in `app/assets/icon/README.md`; the export tool and pinned dependencies are in `scripts/`.

Agent verification: Flutter 3.47.5 dependency resolution, formatting (13 files unchanged), static analysis, all 23 unit/widget tests, all 4 Python script tests, and the final Android debug APK build passed. The final aligned-window exports reproduced identically from the master and passed the safe-circle check and all 19 iOS catalog entries have the correct dimensions and RGB opacity. Circle, rounded-square, squircle, themed and 20–60px previews were visually inspected.

The final aligned-window APK was installed with `adb install -r` on the existing API 36 emulator. Saved preference contents were compared privately before and after replacement and remained byte-for-byte unchanged; no uninstall or data wipe was used. A temporary native instrumentation check loaded the installed application icon, confirmed it is adaptive with a monochrome layer, and rendered both versions on Android API 36. Those native-rendered icons were visually inspected. The computer UI tool could not attach to the emulator, so direct app-drawer/home-screen observation was not performed; native resource rendering is the Android verification completed here. This is agent-run verification, not a user-reported launcher check.

Deferred: iOS launcher appearance requires full Xcode plus an iOS simulator or signed device; only Command Line Tools are installed on this Mac. Physical Android and launcher-specific themed appearance checks remain follow-up validation. No source photo, device screenshots, credentials or raw API data are committed.

## Todo

- [x] Review and choose the final house-outline logo with the owner.
- [x] Save the selected design and an editable master asset in the repository; keep the source photo private.
- [x] Export Android launcher assets, including adaptive foreground/background and a monochrome variant for themed icons.
- [x] Export the iOS app-icon assets and replace the default Flutter icon.
- [x] Check small-size readability and safe placement under common launcher masks.
- [x] Build and verify the icon on the Android emulator without removing saved credentials.
- [x] Verify iOS launcher appearance when full Xcode is available, or record the deferred check and its prerequisite.
- [x] Document the asset locations and repeatable icon-generation workflow.
