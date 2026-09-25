## Purpose

Give Solar Overview a recognizable phone home-screen icon based on the owner's house instead of the default Flutter icon.

## Description

Design a simple house-outline logo using the reference photo supplied in the chat on 2026-09-25. Preserve the house's distinctive steep triangular front gable, narrow vertical attic window, wide three-part upper window, and lower projecting bay window. Simplify those features so the mark remains legible at launcher-icon size.

Use the app's existing green palette with a high-contrast light house outline. Keep the design free of text, brick textures, landscaping, cars, neighboring buildings, and photographic detail. The reference photo remains local; do not upload or commit it. An initial green-and-ivory house-outline concept was generated and shown to the owner in the same chat on 2026-09-25; it has not yet been selected or installed. Final icon installation is follow-up work in this ticket.

Scope: the phone launcher/home-screen icon on Android and iOS, not the Overview navigation icon. Android remains the verification priority; retain iOS assets and record any deferred iOS device checks.

## Todo

- [ ] Review and choose the final house-outline logo with the owner.
- [ ] Save the selected design and an editable master asset in the repository; keep the source photo private.
- [ ] Export Android launcher assets, including adaptive foreground/background and a monochrome variant for themed icons.
- [ ] Export the iOS app-icon assets and replace the default Flutter icon.
- [ ] Check small-size readability and safe placement under common launcher masks.
- [ ] Build and verify the icon on the Android emulator without removing saved credentials.
- [ ] Verify iOS launcher appearance when full Xcode is available, or record the deferred check and its prerequisite.
- [ ] Document the asset locations and repeatable icon-generation workflow.
