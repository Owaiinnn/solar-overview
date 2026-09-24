# Project guidance

Personal Flutter solar overview app. Develop Android first; retain iOS support,
but deferred Xcode/iOS verification must not block Android work. The owner is new
to Flutter: explain handoffs plainly and prefer one copy-paste launch command.

## Starting and finishing a ticket

- Read the selected GitHub issue (including relevant comments) and its copy in
  `docs/tickets/`. Inspect existing code before deciding what remains; unchecked
  boxes are not proof that nothing has been implemented.
- Use `README.md` for current project status and `app/README.md` for code layout
  and development commands. Do not rely on previous chat history.
- Work on one ticket at a time on a feature branch from up-to-date `main`.
  Preserve unrelated local changes; do not switch away from unfinished work.
- Keep commits small and logical. Use a PR; do not push directly to `main`,
  bypass checks, or merge without the owner's explicit request. Preserve logical
  commits with rebase merging when requested. GitHub auto-deletes merged branches;
  local branch cleanup is separate.
- At handoff, record implemented scope, tests actually run, remaining work and
  blockers in the ticket/local copy. Distinguish user-reported testing from tests
  run by the agent. Do not close a ticket with outstanding scope.

## Development and verification

Flutter code is in `app/lib`, unit/widget tests in `app/test`, native tests in
`app/integration_test`, and the standalone API check/tests in `scripts`.
Use the Flutter version pinned in `.github/workflows/checks.yml`.

For app changes, run from `app/`:

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
```

For script changes, run from the repo root:

```sh
python3 -m unittest discover -s scripts -p 'test_*.py'
```

Verify native/plugin changes on Android when a device is available; unit tests
alone do not verify native storage. Report unavailable checks rather than claiming
they passed. Documentation-only changes need link/content and diff checks, not a
device rebuild. CI remains required for merging.

On the owner's Mac, `LOCAL_LAUNCH.md` and `.local/run-android.sh` provide the
one-command emulator launch. They are ignored, machine-local helpers: keep them
untracked and do not assume they exist in a fresh clone. See `app/README.md` for
portable commands. Browser preview shows empty screens without live API testing.

## Data and credentials

- SolarEdge has its own panels. PowerFlex 2000Eco is a battery system with its
  own inverter and two panels. Its API and the smart-meter interface are unknown.
- Keep battery discharge separate from solar production. Do not call SolarEdge
  alone combined production or calculate household surplus without all inputs.
  Missing readings must not become zero; distinguish stale data. The owner does
  not want sample data in the app; keep synthetic fixtures in tests only.
- Credentials are entered in mobile Settings and stored in device secure storage.
  Never commit real credentials, screenshots, raw API responses, credential-bearing
  URLs, or keys in `.env`, app assets or build flags. Use synthetic data in tests.

## Ticket conventions

Every GitHub issue and its local copy in `docs/tickets/` must use exactly these
three Markdown headers, in this order: `## Purpose`, `## Description`, `## Todo`.
Keep the issue title in GitHub's title field, not in a fourth body header.

Purpose explains why; Description contains scope, dependencies, references and
progress notes; Todo contains checkboxes with verifiable completion conditions.
Preserve existing scope, completed items and issue state when reformatting.
Keep GitHub issue bodies and their local ticket copies synchronized. Never add
credentials, private screenshots or raw credential-bearing API responses.
