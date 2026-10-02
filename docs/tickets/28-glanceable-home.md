## Purpose

Make the app's home screen readable at a glance, with a clear solar-production
headline and a polished, continuously animated house-and-solar scene. Keep the
full technical readings easily accessible on a separate Details page.

## Description

Owner-requested follow-up to #4 / PR #27 (2026-10-01). The owner likes the current
Overview implementation and its combined-power-first order. Preserve that work
as the energy Details page rather than extending the dense screen further.
Introduce a new Home landing screen with a compact visual hierarchy: combined
solar power first, explicit partial/unavailable coverage when needed, a short
freshness/status indication, and a clear action to open the full details.

Visual direction: a friendly house with rooftop solar panels and a sun, with soft
rays visibly travelling toward and reaching the panels in a smooth, attractive,
continuous loop. The animation should start automatically and keep running while
Home is visible and the app is active; it is not a one-time entrance animation.
Use the existing green/ivory palette and consider the house identity from #15.
The illustration must support quick reading rather than bury the numbers in
text, decoration or many cards. Aim for the headline, source coverage, scene and
Details action to be visible without scrolling on an ordinary phone; preserve
accessibility with larger text rather than shrinking essential labels.

The closest existing animation ticket is #11, "Add animated energy icons with a
green flow effect", which is already closed. This new ticket carries its reusable
animation, offline asset, licensing, accessibility and lifecycle requirements
forward for the broader Home scene. The old lightning-bolt treatment can be a
supporting accent if useful; it is not the required centrepiece of this design.
Do not reopen #11 or create a duplicate animation implementation for this scope.
Evaluate suitable free reusable assets/Lottie first, then Flutter effects or
custom drawing when they better support the full scene; record the choice and
rendering/dependency cost. Check asset and library licenses independently,
including modification and redistribution in this public repository, and retain
attribution/notices. No paid export/runtime subscription or remote asset loading.

SolarEdge and SolaX each have their own panels and inverter. The house illustration
is a visual summary, not a newly verified wiring diagram. Preserve #4's AC-only
combination, timestamp-alignment and freshness rules, named partial subtotals,
missing-versus-zero distinction and qualified SolaX energy provenance. Do not add
another calculation or request loop just for Home. Both screens use the same
controllers, cached readings and provider refresh waits.

Motion is illustrative: rays do not measure irradiance, prove sunny weather or
claim continuously updated API readings. Keep a subtle decorative loop for
loading/zero/stale/unavailable states, but do not show confirmed generation or
measured energy flow when the readings do not establish it. Provide a quiet
zero-production/night treatment where supported; no unverified weather claims or
weather API dependency. Respect reduced-motion/disabled-animation preferences
with a static scene, and pause tickers offscreen/in the background to avoid
unnecessary battery use. Status must remain understandable without motion/color.

PowerFlex house-battery integration remains separate later work in #6, and the
smart meter remains #7. Leave room in the design for those future sources without
showing invented battery charge/discharge, household flow, surplus or appliance
advice. Neither integration is a prerequisite for this solar Home screen.
History/appliance features remain in #5/#8; this ticket only preserves their
navigation. No sample mode: synthetic fixtures belong only in tests and isolated
design previews, never in the shipped app or normal browser preview.

Dependencies: #4 / PR #27 provides the readings and current Overview to reuse.
Existing device/provider checks in #19/#25/#30 remain tracked separately;
this redesign does not imply those checks have passed. Android first; retain
responsive iOS layouts and record deferred native iOS verification explicitly.

Implementation and agent verification (2026-10-02):

- Home is now the default landing page; View details opens the preserved Overview.
  Toolbar and Android Back return Home. Settings, History and Appliances remain
  available, and Details keeps its scroll/expansion state in the existing stack.
- Added original offline green/ivory house artwork, rooftop panels, a sun and
  repeating ray arrivals for positive eligible production. Quiet states retain a
  muted decorative halo; disabled animation/accessibility and offscreen/background
  states stop the controller. No provider requests or new dependencies were added.
  See [scene design and asset/license evaluation](https://github.com/Owaiinnn/solar-overview/blob/3f06c4e/docs/home-scene.md).
- Home reuses ProductionTotal and the same controllers, caches and refresh waits.
  Covers fresh/saved, partial, zero, loading, missing/stale, failed requests and
  timestamp mismatch. Missing data remains unavailable; source badges are textual.
- Agent ran Flutter 3.47.5 dependency resolution, formatting checks, static analysis
  (no issues), all 125 unit/widget tests, Android debug build and browser release
  build. Synthetic tests cover Home/Details transitions, Android Back, guarded states,
  aging, no added SolaX calls, reduced motion, ancestor TickerMode and app lifecycle.
  Layout tests passed at 360×640 and 390×844 with normal and doubled text size.
- Agent visually checked Android API 36: both live source connections, combined
  headline, looping ray scene, Details, expanded SolaX MPPT/temperature/counters,
  persistent refresh waits, Android Back and cold restart. Both recent saved sources
  reappeared after force-stop/reopen. No live connection replacement/removal was
  tested, and no provider-app comparison is claimed.
- Agent checked Chrome's empty Home/Details preview at 360×640 and 390×844 viewports.
  Native iOS was not run: only Command Line Tools are installed. Native iOS
  layout/motion/lifecycle and physical Android rendering remain explicitly in #19;
  provider comparisons remain #25/#30. No owner-run feature testing is claimed.
- Initial scene Android profile check passed (before the logo/loading revision): 715 frames over 12 seconds after
  two seconds of warm-up. Build p50/p95: 0.401/0.797 ms; raster p50/p95:
  15.806/18.012 ms. 194 frames exceeded 16.67 ms in build or raster. These emulator
  numbers do not establish physical-device 60 fps; the physical check is in #19.
- Verification incident: Flutter drive's default cleanup uninstalled the app and
  cleared emulator connections. With the owner's approval, the pre-existing startup
  snapshot was restored and the final app reinstalled with data preserved. Both
  connections and saved readings were verified afterward. The documented benchmark
  command now requires --keep-app-running to prevent cleanup removal.

Owner-requested design/loading revision (2026-10-02, PR #33):

- Rebuilt the front of the illustrated house using the app logo's exact geometry:
  steep roof, narrow attic window, centered upper three-pane window, projecting
  bay with aligned dividers, and the door to its right. Side roof/panels remain
  illustrative. The launcher logo itself is unchanged.
- Startup now says Loading… and Checking your solar sources while connections
  open or connected providers refresh. The house gently bounces on a 1.5-second
  cycle, with a changing contact shadow; it settles when loading finishes, even
  on error. Existing eligible readings remain visible. Reduced motion stays static,
  background/offscreen suspension remains in place, and no artificial wait or
  provider call was added.
- Agent checks: dependency resolution, formatting, clean analysis, 129 passing
  unit/widget tests, Android debug build, and passing isolated Android loading
  integration test with two visually inspected loading frames and completion.
  Normal Android startup/updated artwork was inspected with the existing saved
  sources intact. The loading test used only in-memory synthetic state and
  --keep-app-running, preserving real device storage. Native iOS remains in #19.

The implementation is ready for PR review. Leave this issue open until its PR is
merged; native/physical follow-ups above remain open in #19.

## Todo

- [x] Produce a reviewable Home design with a prominent combined-power headline, compact source coverage/freshness, house-and-solar scene and obvious Details action.
- [x] Make Home the default landing screen; move the existing Overview content into a clearly named Details page and provide obvious navigation back without losing readings or state.
- [x] Keep Home readable at a glance without scrolling at normal phone text size; support narrow screens and larger text without overflow or hiding essential status.
- [x] Keep the full per-source readings, timestamps, errors, refresh actions, energy qualifications and MPPT/temperature details available on Details.
- [x] Select and document a free animation approach and any asset sources, licenses, redistribution/modification rights, attribution and rendering/dependency tradeoffs; bundle assets for offline use.
- [x] Build a polished house, rooftop panels and sun scene with a smooth automatic repeating ray-to-panel animation while Home is visible and active.
- [x] Define fresh production, partial coverage, zero production, loading, stale, offline and unavailable presentation; keep decorative motion distinct from confirmed generation and do not invent weather, battery or household flows.
- [x] Share the existing source controllers and guarded AC total between Home and Details; navigation/animation must not introduce API polling, reset cooldowns or alter credentials.
- [x] Support a static reduced-motion fallback, accessible status labels and offscreen/background animation suspension/resumption.
- [x] Preserve Settings, History and Appliances navigation and keep the separate future battery/meter scope out of this implementation.
- [x] Verify screen transitions, no duplicate requests, source/freshness/partial states, reduced motion and lifecycle behavior with synthetic unit/widget tests.
- [x] Visually verify the continuously looping scene, readability and Details flow on Android, plus iOS-sized layouts and browser preview; record frame/rendering performance and any deferred native iOS checks. Keep private screenshots out of git.
