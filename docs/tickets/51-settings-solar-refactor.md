## Purpose

Make the existing Flutter code easier to maintain under the project coding guidelines while preserving current behavior and provider safeguards.

## Description

Owner-approved follow-up to the code review on 2026-10-06. Implement from current main, keeping the unfinished battery branch and unrelated local Home edit untouched.

Scope:
- Extract the SolarEdge connection form into a dedicated settings component, and separate Settings page composition from app navigation.
- Share the solar reading freshness enum, timestamp checks and 30-minute threshold between SolarEdge and SolaX. Preserve unknown/future timestamps and the exact stale boundary; local P1/battery receipt policies remain separate.
- Share combined/partial production titles and source-coverage text between Home and Details, preserving Home's loading copy and existing eligibility/skew guards.

Follow docs/coding-guidelines/general.md. Keep authentication, persistence, recovery and refresh behavior provider-specific. Add no dependencies, speculative generic controller framework, or explanatory source comments. Existing user-facing behavior, wording, styling and saved connections must remain intact.

## Todo

- [ ] Extract SolarEdge settings and Settings page composition while preserving form state, validation, secret clearing, replacement/removal cancellation and tab navigation.
- [ ] Centralize solar freshness rules without changing missing/future/boundary behavior or local-source policies.
- [ ] Share production titles and coverage text across Home and Details, preserving empty/loading, partial, combined and time-mismatch states.
- [ ] Run meaningful regression coverage plus pub get, formatter, analyzer and the full unit/widget suite with the pinned Flutter SDK.
- [ ] Perform a focused Android walkthrough of Home, Details and Settings if available; record actual verification and any unavailable checks.
- [ ] Synchronize this issue and its local ticket, open a PR with Closes linkage, and leave merging to the owner.
