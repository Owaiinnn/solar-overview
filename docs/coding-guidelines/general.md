# Solar Overview coding guidelines

Read this before implementation and use it for self-review. These rules adapt the
owner's `code_review_general_overview.md` and selected principles from
`code_review_checklist.md` for this Flutter/Dart project. The project copy is
self-contained; agents do not need the owner's separate dev-workflow repository.
Workflow, verification commands and credential rules remain in
[AGENTS.md](../../AGENTS.md).

## Comments and documentation

- Prefer descriptive names and small, focused functions over explanatory notes.
- Do not add inline comments, block comments, Dart documentation comments or
  TODO/FIXME notes without the owner's explicit approval first. When a comment
  is necessary, show the proposed wording and explain the non-obvious behavior
  it protects. Approval for one comment is not blanket approval for later ones.
- Put architecture, provider quirks and design rationale in relevant `docs/`
  files; keep unfinished work and verification evidence in tickets. This rule
  concerns source-code notes, not ordinary Markdown documentation.
- Remove redundant notes during the planned cleanup. Preserve useful rationale
  in documentation before removing its source comment. Do not change behavior
  as a side effect of comment removal.
- Keep required license/copyright notices, generated-file markers, shebangs and
  functional tooling directives. Do not delete them as prose cleanup. Ask before
  adding a new suppression or explanatory note in maintained code; avoid editing
  generated or third-party files by hand.

## Responsibilities and reuse

- Widgets present state and forward user actions. Provider clients handle HTTP
  and parsing; controllers own connection/refresh lifecycles; stores persist data.
  Keep business calculations out of painters and widget build methods.
- Reuse existing provider, storage, time and error-handling infrastructure before
  introducing alternatives. Extract repeated behavior when it has real consumers.
- Keep small, single-use logic local unless separation makes a complex concern
  clearer or independently testable. Avoid forwarding wrappers and speculative
  frameworks, repositories or generic helpers.
- Keep functions and files focused. Split long operations into named steps when
  that improves understanding, without forcing one file per type or method.

## Dart and naming

- Follow the existing Dart analyzer and formatter. Use `UpperCamelCase` for types,
  `lowerCamelCase` for members and constants, and `snake_case.dart` for files.
- Prefer `final` for values that are not reassigned and `const` when appropriate.
  Use typed models and null safety; validate external JSON at the boundary rather
  than spreading `dynamic`, casts or non-null assertions through the UI.
- Names describe the action or state in the domain. Distinguish reading, fetching,
  creating and navigating; avoid vague `handle*` names when a concrete verb fits.
- Prefer enums or explicit state types when several booleans allow contradictory
  states. Derived values should be computed from their owning state.
- Choose a switch, map or conditional for clarity. Do not mechanically replace
  every branch or import Vue/TypeScript naming and file-layout rules.

## State and asynchronous work

- Give each state one owner. Keep a connection-edit draft separate from the saved
  connection, and share existing source controllers between Home and Details.
- Use one loading flag per distinct operation. Independent providers must retain
  independent loading/error states so one failure cannot hide healthy readings.
- Make sequencing explicit. Run independent requests concurrently only when
  provider quotas and authentication permit it. Await dependencies in order.
- Prevent duplicate requests and stale completions from replacing newer state.
  Reset in-flight UI state on failure as well as success. Preserve persisted
  request waits and atomic credential/cache rules.
- Dispose controllers/listeners correctly. Stop animation and foreground-only
  refresh when offscreen or backgrounded; never fetch from a paint/build loop.

## Energy data and failures

- Missing, failed, unknown and stale readings must not become zero. Preserve
  source measurement time, receipt time, units, signs and source coverage.
- Keep power (W/kW) separate from energy (Wh/kWh), AC from DC, and battery discharge
  from solar production. Grid exchange alone is not household consumption or
  evidence of solar surplus. Follow the verified boundary/timing policy.
- Use safe, actionable user errors. Never expose tokens, private addresses or raw
  provider exceptions/responses through logs, screenshots or test failure output.
- Preserve existing guards unless their removal is an intentional requirement
  change. Check zero, negative, missing, malformed, stale and boundary values.
- Keep decorative scene state separate from measured energy indicators. Preserve
  the shared house geometry and vary layers rather than duplicating the artwork.

## UI, accessibility and performance

- Follow the agreed house design, theme and existing screen patterns. Keep shared
  widget styling with that widget, and use clear, consistent user-facing copy.
- Check loading, empty, error, saved and editing states at small phone sizes and
  large text settings. Status must be readable without color or animation.
- Respect reduced motion and app lifecycle. Animate only what needs repainting;
  avoid rebuilding the whole page every frame or adding unneeded dependencies.
- Validate user inputs with useful field-level feedback. Preserve working saved
  settings when testing a replacement fails.

## Self-review

- Check the diff against the selected ticket and preserve unrelated user edits.
  Track broader refactors separately.
- Verify behavior with meaningful tests for affected rules and failure paths;
  reuse synthetic fixtures and keep sample data out of the shipped app.
- Run the applicable checks in `AGENTS.md`. Documentation-only changes need
  link/content and diff checks. Do not add tests that merely mirror implementation.
- Record checks actually run, remaining work and unavailable device verification
  in the ticket. Update related documentation when its described behavior changes.

## Implementation references

Provider timing, storage and security rationale lives with the
[SolarEdge](../solaredge-check.md#flutter-request-and-storage-safeguards),
[SolaX](../solax-check.md#client-and-persistence-safeguards) and
[P1](../p1-check.md) documentation. See the [Home scene](../home-scene.md) for
animation/geometry and the [icon workflow](../../app/assets/icon/README.md) for
asset export. [Build configuration](../build-configuration.md) records platform
configuration rationale and the current signing limitation.
