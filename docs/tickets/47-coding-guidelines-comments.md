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

Planning handoff: project guide and AGENTS.md entry point are prepared on the
documentation branch. Existing comments have been inventoried; cleanup remains
implementation work for this issue. Agent-run documentation checks passed for
ticket headers, relative links, final newlines, absence of token-shaped text and
`git diff --check`. No runtime code changed, so Flutter/device tests were not run.
The planning work uses a separate worktree and preserves the existing battery/Home
changes. All five affected GitHub issue bodies must match their local copies.

## Todo

- [x] Review both owner-supplied guides and prepare a self-contained Flutter/Dart adaptation in `docs/coding-guidelines/general.md`.
- [x] Add an explicit root AGENTS.md instruction to read the guide before coding/review, including the owner's comment-approval rule.
- [ ] Merge the documentation PR so the guidelines apply to future branches from main.
- [ ] Audit maintained source comments and remove redundant notes without changing behavior or generated/third-party files.
- [ ] Preserve useful technical rationale in relevant Markdown documentation and retain required legal/tooling content.
- [ ] Obtain explicit owner approval before any necessary new/reworded explanatory code comment is added.
- [ ] Run applicable Flutter/script checks after source cleanup and review the diff for behavior changes; keep issue and local copy synchronized.
