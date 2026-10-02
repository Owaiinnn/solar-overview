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

## Todo

- [ ] Produce a reviewable Home design with a prominent combined-power headline, compact source coverage/freshness, house-and-solar scene and obvious Details action.
- [ ] Make Home the default landing screen; move the existing Overview content into a clearly named Details page and provide obvious navigation back without losing readings or state.
- [ ] Keep Home readable at a glance without scrolling at normal phone text size; support narrow screens and larger text without overflow or hiding essential status.
- [ ] Keep the full per-source readings, timestamps, errors, refresh actions, energy qualifications and MPPT/temperature details available on Details.
- [ ] Select and document a free animation approach and any asset sources, licenses, redistribution/modification rights, attribution and rendering/dependency tradeoffs; bundle assets for offline use.
- [ ] Build a polished house, rooftop panels and sun scene with a smooth automatic repeating ray-to-panel animation while Home is visible and active.
- [ ] Define fresh production, partial coverage, zero production, loading, stale, offline and unavailable presentation; keep decorative motion distinct from confirmed generation and do not invent weather, battery or household flows.
- [ ] Share the existing source controllers and guarded AC total between Home and Details; navigation/animation must not introduce API polling, reset cooldowns or alter credentials.
- [ ] Support a static reduced-motion fallback, accessible status labels and offscreen/background animation suspension/resumption.
- [ ] Preserve Settings, History and Appliances navigation and keep the separate future battery/meter scope out of this implementation.
- [ ] Verify screen transitions, no duplicate requests, source/freshness/partial states, reduced motion and lifecycle behavior with synthetic unit/widget tests.
- [ ] Visually verify the continuously looping scene, readability and Details flow on Android, plus iOS-sized layouts and browser preview; record frame/rendering performance and any deferred native iOS checks. Keep private screenshots out of git.
