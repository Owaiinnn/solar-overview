# Project guidance

Personal Flutter solar overview app. Develop Android first; retain iOS support,
but deferred Xcode/iOS verification must not block Android work. The owner is new
to Flutter: explain handoffs plainly and prefer one copy-paste launch command.

## Coding guidelines

- Before writing or reviewing code, read and follow
  [the project coding guidelines](docs/coding-guidelines/general.md).
- Do not add explanatory code comments, documentation comments or TODO notes
  without first explaining why one is necessary and receiving the owner's
  explicit approval. Prefer clear code and Markdown documentation. Preserve
  required license notices and functional tooling directives.

## Starting and finishing a ticket

- Read the selected GitHub issue (including relevant comments) and its copy in
  `docs/tickets/` (or `docs/tickets/done/` for completed tickets). Inspect existing
  code before deciding what remains; unchecked boxes are not proof that nothing
  has been implemented.
- Keep both READMEs concise: `README.md` covers purpose and technology;
  `app/README.md` covers built features, setup and development commands. Future
  plans may be described generally. Treat READMEs as stable reference documents,
  not status reports; update them only when their documented behavior or setup
  changes. Do not add specific ticket references, progress updates or verification
  logs to either README; keep those in `docs/tickets/`. Do not rely on previous
  chat history.
- Work on one ticket at a time on a feature branch from up-to-date `main`.
  Preserve unrelated local changes; do not switch away from unfinished work.
- Keep commits small and logical. Use a PR; do not push directly to `main`,
  bypass checks, or merge without the owner's explicit request. Preserve logical
  commits with rebase merging when requested. GitHub auto-deletes merged branches.
- After every PR you merge, finish local cleanup: preserve unrelated uncommitted
  work, switch the primary checkout to `main`, run `git pull --ff-only origin main`,
  and delete the merged local branch. For a branch checked out in a worktree,
  remove the worktree only when no local work or needed files would be lost;
  otherwise detach it before deleting the branch. Prefer `git branch -d`; after
  a rebase or squash merge, use `-D` only after verifying the PR is merged and
  every local change is included in `main` or otherwise preserved. Never discard
  unmerged commits or local edits to complete cleanup. Verify the primary checkout
  is on updated `main` and the merged local branch is gone before handing off;
  report any blocker explicitly.
- At handoff, record implemented scope, tests actually run, remaining work and
  blockers in the ticket/local copy. Distinguish user-reported testing from tests
  run by the agent.
- After a ticket’s implementation PR is merged, close its linked GitHub issue
  and verify that the remote issue is closed; merging alone is not completion.
  Use `Closes #N` in the PR when it completes the ticket. If verification or scope
  is explicitly deferred, preserve it in a linked follow-up issue before closing
  the merged implementation ticket. Keep local ticket copies synchronized.
- Once the implementation is merged and the GitHub issue is verified closed,
  move its local Markdown file with `git mv` from `docs/tickets/` to
  `docs/tickets/done/`, preserving its filename, scope and verification history.
  Keep open tickets and open follow-ups directly in `docs/tickets/`. A merged PR
  or checked-off checklist alone is not enough to archive a ticket; deferred work
  must have linked open follow-ups before the implementation issue is closed.
  Update links and path references affected by the move and commit the archive
  change through the normal PR workflow (a follow-up documentation PR if needed).
  Do not delete completed ticket files. If an issue is reopened, move its file
  back to `docs/tickets/`.

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

Use `--no-uninstall` with `flutter test integration_test` to preserve the app
and its saved connections; the Flutter default uninstalls the app after tests.
Use `--keep-app-running` with `flutter drive` for the same reason.

Verify native/plugin changes on Android when a device is available; unit tests
alone do not verify native storage. Report unavailable checks rather than claiming
they passed. Documentation-only changes need link/content and diff checks, not a
device rebuild. CI remains required for merging.

Actively use direct mobile UI control when it helps verify a change. The owner
explicitly welcomes and authorizes ADB control of the Android emulator for app
testing: inspect screenshots/UI hierarchy, tap, swipe, type, navigate screens,
and background, force-stop or reopen Solar Overview. Do not default to asking
the owner to click through flows that the agent can test itself. Check available
devices with `adb devices`; on the owner's Mac, ADB is normally at
`/Users/owain/Library/Android/sdk/platform-tools/adb`. Use the connected device ID,
not a hardcoded assumption. Native desktop control is another option when its
tools expose the emulator window. Follow the active tool and permission rules.

For relevant mobile changes, supplement automated tests with a focused visual
walkthrough of the affected flow. Check rendered results after interactions and
report what was actually verified. Useful checks include navigation, live refresh,
cached readings, persistent refresh waits and cold restart. Temporary emulator
network changes for offline tests must be restored. Preserve existing live
connections; test cancellation paths unless actual replacement/removal is part
of the authorized task. Respect real provider cooldowns and keep screenshots,
UI dumps and credentials out of version control. If no emulator is available,
use the local launch helper when available or report the unavailable check.

On the owner's Mac, `LOCAL_LAUNCH.md` and `.local/run-android.sh` provide the
one-command emulator launch. They are ignored, machine-local helpers: keep them
untracked and do not assume they exist in a fresh clone. See `app/README.md` for
portable commands. Browser preview shows empty screens without live API testing.

## Data and credentials

- Solar production sources are only SolarEdge and SolaX panels/inverter. The
  INDEVOLT inverter card repeats the existing SolarEdge system, not a third source.
  Read-only Mac checks on 2026-10-04 verified separate local HTTP access to the
  INDEVOLT battery and P1-2WR reader. P1 Flutter integration and live emulator
  checks are implemented in #7; battery integration is implemented in #6. See their
  ticket copies and follow-ups #42 (P1) and #53 (battery) for remaining validation. The owner
  chose home-network-only access: no cloud/MQTT service or gateway for this scope.
  The owner confirmed both solar systems and the battery share the P1 meter.
  Battery usable capacity and exact AC/bypass topology still need verification;
  #43 owns timestamp-aligned household calculation. Do not infer household use from SolaX summary counters or
  the battery's zero load field, or mix pack DC power with AC grid/solar readings.
  Preserve source timing: receipt time is not a measurement timestamp, and the
  combined-solar freshness rules do not establish a valid live household balance.
  See `docs/solax-check.md` and #21 for existing SolaX access/mapping.
- Keep battery discharge separate from solar production. Do not call SolarEdge
  alone combined production or calculate household surplus without all inputs.
  Missing readings must not become zero; distinguish stale data. The owner does
  not want sample data in the app; keep synthetic fixtures in tests only.
- Credentials are entered in mobile Settings and stored in device secure storage.
  Never commit real credentials, screenshots, raw API responses, credential-bearing
  URLs, or keys in `.env`, app assets or build flags. Use synthetic data in tests.

## Ticket conventions

Every GitHub issue and its local copy in `docs/tickets/` or
`docs/tickets/done/` must use exactly these three Markdown headers, in this order:
`## Purpose`, `## Description`, `## Todo`.
Keep the issue title in GitHub's title field, not in a fourth body header.

Purpose explains why; Description contains scope, dependencies, references and
progress notes; Todo contains checkboxes with verifiable completion conditions.
Preserve existing scope, completed items and issue state when reformatting.
Keep GitHub issue bodies and their local ticket copies synchronized. Never add
credentials, private screenshots or raw credential-bearing API responses.
