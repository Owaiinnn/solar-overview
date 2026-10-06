## Purpose

Make the existing Flutter code easier to maintain under the project coding guidelines while preserving current behavior and provider safeguards.

## Description

Owner-approved follow-up to the code review on 2026-10-06. Implement from current main, keeping the unfinished battery branch and unrelated local Home edit untouched.

Scope:
- Extract the SolarEdge connection form into a dedicated settings component, and separate Settings page composition from app navigation.
- Share the solar reading freshness enum, timestamp checks and 30-minute threshold between SolarEdge and SolaX. Preserve unknown/future timestamps and the exact stale boundary; local P1/battery receipt policies remain separate.
- Share combined/partial production titles and source-coverage text between Home and Details, preserving Home's loading copy and existing eligibility/skew guards.

Follow docs/coding-guidelines/general.md. Keep authentication, persistence, recovery and refresh behavior provider-specific. Add no dependencies, speculative generic controller framework, or explanatory source comments. Existing user-facing behavior, wording, styling and saved connections must remain intact.

Implementation and verification (2026-10-06):
- Implemented on `refactor/51-settings-solar` from current main in an isolated worktree. The original battery branch and its uncommitted Home caption edit remain untouched.
- `settings.dart` composes connection cards; `solaredge_settings.dart` owns the SolarEdge form and its draft state. Keep-alive preserves the draft when the card scrolls out of view, matching the former page-owned lifetime.
- `solar_freshness.dart` owns the shared enum, timestamp checks and 30-minute cutoff. Provider-specific controllers/storage and local P1 freshness remain unchanged.
- `ProductionTotal` supplies the shared partial/combined title and coverage. Home retains its loading copy; source eligibility and five-minute skew checks are unchanged.
- Android startup exposed an existing negative minimum-height assertion before window metrics arrive. A separate fix clamps Home's minimum height to zero; a regression checks zero-height startup and recovery to normal height.
- Agent ran Flutter 3.47.5 dependency resolution, formatting, analysis, all 174 unit/widget tests and diff checks successfully. New regressions cover both providers' exact freshness boundaries, Home/Details coverage states, scrolling/tab draft retention, cancellation and startup layout. Existing tests cover storage failure, request waits, secret clearing and small screens/large text.
- Agent built and ran the final debug APK on the API 36 Android emulator. Visually checked Home/Details production coverage, saved-reading presentation, the SolarEdge replacement form with an empty key, replacement cancellation and the removal dialog's Cancel action. Saved connections remained intact. Cold restart rendered Home with recent saved readings; no Flutter assertion/error markers appeared in the restarted emulator log. No credentials were entered or connections replaced/removed. Screenshots and UI dumps remain outside version control.
- PR: https://github.com/Owaiinnn/solar-overview/pull/52 (Closes #51). Both GitHub Flutter check runs passed for the implementation commit. The ticket remains open pending owner-requested merge; archive only after merge and confirmed issue closure.
- Physical-device and iOS checks were not run. No native/plugin code changed; existing device-verification work remains in #19/#25/#30/#42. No implementation blockers remain.

## Todo

- [x] Extract SolarEdge settings and Settings page composition while preserving form state, validation, secret clearing, replacement/removal cancellation and tab navigation.
- [x] Centralize solar freshness rules without changing missing/future/boundary behavior or local-source policies.
- [x] Share production titles and coverage text across Home and Details, preserving empty/loading, partial, combined and time-mismatch states.
- [x] Run meaningful regression coverage plus pub get, formatter, analyzer and the full unit/widget suite with the pinned Flutter SDK.
- [x] Perform a focused Android walkthrough of Home, Details and Settings if available; record actual verification and any unavailable checks.
- [x] Synchronize this issue and its local ticket, open a PR with Closes linkage, and leave merging to the owner.
