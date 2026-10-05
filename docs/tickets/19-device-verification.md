## Purpose

Complete the remaining live-data and device verification from the merged Flutter foundation and SolarEdge integration tickets.

## Description

Follow-up to #2 and #3, whose implementation was merged in PRs #10, #14 and #18. The owner requested that merged tickets be closed on 2026-09-28. These outstanding checks are carried forward explicitly; closing the implementation tickets does not claim that these checks passed.

Android remains the priority. Earlier live connection, persistence and removal checks were confirmed by the owner on the Android emulator. Automated failure-path and native secure-storage tests used synthetic records. Physical Android testing and full Xcode/iOS verification remain pending. Enter real credentials only in mobile Settings; do not post keys, site identifiers, private screenshots or raw responses.

Home follow-up from #28: native iOS Home/Details layout, accessibility motion
preferences and lifecycle behavior remain unverified. Also check the looping scene
on a physical Android phone; the emulator profile run is not a physical-device
performance result. Keep these separate from owner-reported provider comparisons.

Backlog reconciliation (2026-10-04): #28 / merged PR #33 records agent-run Android
emulator checks on 2026-10-02 with both live sources, force-stop/reopen, saved
readings and persistent refresh waits. Credit that evidence below; it does not
establish physical-device behavior, provider-app agreement or the site timezone.
The 2026-10-04 battery/P1 checks were Mac API probes only. New local-source Android
and off-network checks are acceptance work in #6/#7, with new scene checks in #35;
they have not passed merely because those devices respond from the Mac.

House artwork follow-up from #38 (2026-10-05): the corrected facade, entrance
hedge and regenerated launcher assets were checked on the API 36 emulator.
Physical Android launcher/theme masks and native iOS icon/Home appearance still
need verification. Inspect the revised artwork rather than the superseded #15
geometry; emulator and generated-export checks do not establish physical results.

## Todo

- [x] Confirm a real SolarEdge reading on the Android emulator with the updated Home/Details app (agent-run #28 / PR #33, 2026-10-02).
- [ ] Confirm the configured SolarEdge site timezone against the provider/site information.
- [x] Fully close/reopen the Android emulator app before the refresh wait expires; confirm saved readings and the remaining wait (agent-run #28 / PR #33, 2026-10-02).
- [ ] After the wait, verify a successful live refresh; then verify offline retention after a later wait and stale labeling after 30 minutes.
- [ ] Verify connection, persistence after close/reopen, and removal on a physical Android phone.
- [ ] Install full Xcode and verify the iOS build and launch on an iPhone simulator or device.
- [ ] Verify native iOS credential/cache persistence and removal, plus launcher appearance.
- [ ] Record which checks were performed by the owner versus the agent, without exposing private data.
- [ ] Verify Home/Details layout, reduced motion and background/resume behavior on native iOS, and scene smoothness/rendering cost on a physical Android phone (follow-up to #28).

- [ ] Verify the #38 revised house/hedge icon on a physical Android launcher, including a supported themed-icon mask, and inspect its Home scene.
- [ ] Verify the #38 revised icon and Home scene on native iOS once full Xcode and an iOS simulator or device are available.
