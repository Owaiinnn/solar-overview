## Purpose

Complete the remaining live-data and device verification from the merged Flutter foundation and SolarEdge integration tickets.

## Description

Follow-up to #2 and #3, whose implementation was merged in PRs #10, #14 and #18. The owner requested that merged tickets be closed on 2026-09-28. These outstanding checks are carried forward explicitly; closing the implementation tickets does not claim that these checks passed.

Android remains the priority. Earlier live connection, persistence and removal checks were confirmed by the owner on the Android emulator. Automated failure-path and native secure-storage tests used synthetic records. Physical Android testing and full Xcode/iOS verification remain pending. Enter real credentials only in mobile Settings; do not post keys, site identifiers, private screenshots or raw responses.

## Todo

- [ ] On Android with the updated app, confirm a real SolarEdge reading and the site timezone.
- [ ] Fully close/reopen within 15 minutes; confirm saved readings and the remaining refresh wait.
- [ ] After the wait, verify a successful live refresh; then verify offline retention after a later wait and stale labeling after 30 minutes.
- [ ] Verify connection, persistence after close/reopen, and removal on a physical Android phone.
- [ ] Install full Xcode and verify the iOS build and launch on an iPhone simulator or device.
- [ ] Verify native iOS credential/cache persistence and removal, plus launcher appearance.
- [ ] Record which checks were performed by the owner versus the agent, without exposing private data.
