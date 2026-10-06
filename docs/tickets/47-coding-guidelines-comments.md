## Purpose

Make project coding conventions discoverable to agents and remove unnecessary
source-code notes while keeping the code and important rationale understandable.

## Description

Owner-requested on 2026-10-05. Use a short mandatory instruction in root
`AGENTS.md` to read `docs/coding-guidelines/general.md` before implementation and
review. Keep the guide in this repository so fresh clones and worktrees can use
it without access to the owner's separate dev-workflow checkout.

Adapt the principles from `code_review_general_overview.md` and useful parts of
`code_review_checklist.md`. Keep separation of concerns, clear naming, reuse,
state ownership, safe async work, honest errors, accessibility and behavioral
testing. Replace Vue/Pinia/Vuetify/TypeScript/Cypress-specific prescriptions with
Dart/Flutter and this project's controller/storage/painter conventions. Do not
copy unrelated team process, Jira references or framework-specific naming rules.

Owner policy: do not add explanatory source comments, documentation comments or
TODO/FIXME notes without first explaining why they are necessary and receiving
explicit approval. Prefer readable code and Markdown documentation. Preserve
required legal notices, shebangs, generated-file markers and functional tooling
directives; those are not disposable prose notes.

Audit maintained Dart code/tests, Python scripts and maintained native/build
configuration. Remove redundant comments; move still-useful provider timing,
quota, field-provenance, security and animation rationale to appropriate docs
before removing notes. Keep behavior unchanged and avoid bulk editing generated
or third-party files. Any proposed new/reworded explanatory comment needs the
owner's approval before addition.

Planning handoff: the self-contained guide and AGENTS.md entry point were merged
into main in `fc90995`; implementation starts from main at `e819e37` in a separate
worktree. The existing battery branch and uncommitted Home edit remain untouched.

Implementation handoff — 2026-10-06: audited maintained Dart source/tests, Python
scripts, Android build/manifests/resources, the iOS test stub and browser/build
configuration. Removed redundant prose and template TODOs. Useful timing, quota,
field-provenance, security, storage and animation rationale is retained in the
SolarEdge/SolaX/P1 guides, Home scene guide, icon guide and
[build configuration](../build-configuration.md), linked from the coding guide.
No new or reworded explanatory source comments were needed or added. Shebangs,
preprocessor directives, the analyzer suppression and generated-file markers are
preserved. The two Python module docstrings used by argparse remain executable
CLI help content. Generated assets, Xcode project/storyboard annotations, Flutter
metadata, lockfiles and third-party files were not edited.

Agent-run verification passed with Flutter 3.47.5 / Dart 3.13.4: dependency
resolution, formatting of all 49 Dart files (zero changes), analysis (no issues),
166 unit/widget tests and all four Python script tests. Analysis/tests used
`--no-pub` after successful dependency resolution. The first sandboxed Flutter
test attempt could not bind the runner's loopback socket; the permitted rerun
passed. A focused equivalence check verified unchanged non-comment Dart/native/
build text, XML element trees and Python ASTs apart from removed unused docstrings;
both argparse descriptions are unchanged. Relative Markdown links, ticket headers,
final newlines and `git diff --check` passed. No device rebuild, native integration
test, icon regeneration or visual walkthrough was run because runtime/configuration
behavior and assets did not change. No live providers or saved connections were
accessed. No user-run testing is claimed.

Remaining: implementation PR review, required CI and owner-requested merge, then
verify issue closure and archive this local ticket through the normal PR workflow.
There are no implementation blockers.

## Todo

- [x] Review both owner-supplied guides and prepare a self-contained Flutter/Dart adaptation in `docs/coding-guidelines/general.md`.
- [x] Add an explicit root AGENTS.md instruction to read the guide before coding/review, including the owner's comment-approval rule.
- [x] Merge the documentation PR so the guidelines apply to future branches from main.
- [x] Audit maintained source comments and remove redundant notes without changing behavior or generated/third-party files.
- [x] Preserve useful technical rationale in relevant Markdown documentation and retain required legal/tooling content.
- [x] Obtain explicit owner approval before any necessary new/reworded explanatory code comment is added (none needed or added).
- [x] Run applicable Flutter/script checks after source cleanup and review the diff for behavior changes; keep issue and local copy synchronized.
