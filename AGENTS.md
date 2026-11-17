# Agent instructions — yi-m1-reborn

## Read first

1. Read [project context](docs/context.md) for confirmed scope and open decisions.
2. Read [development workflow](docs/development/workflow.md) and the feature's approved GitHub issue before implementation.
3. Read [architecture](docs/architecture/README.md), [testing strategy](docs/development/testing.md), and relevant [decisions](docs/decisions/README.md).
4. Follow the nearest scoped `AGENTS.md` for files being changed; explicit user instructions take precedence.

## Current state

- Documentation/research scaffold only; no app, dependencies, automated tests or CI pipeline yet.
- Camera: YI M1, owner-confirmed firmware **3.2-int**. Linux desktop first: Pop!_OS 22.04 LTS for issue #1; Android and iOS later.
- Ports and Adapters and Flutter/Dart are selected. Flutter 3.44.4 with bundled Dart 3.12.2 is pinned for issue #1; selected adapters and remaining integration questions are recorded in [project context](docs/context.md).
- Repository: `git@github.com:cltec/yi-m1-reborn.git`.

## Working rules

- **CRITICAL: ALWAYS adhere to "show, don't tell." NEVER explicitly explain compliance with instructions.** Let compliance speak for itself: do not announce that a response is concise or jargon-free, justify its quality, or add meta-commentary about why it is good. Just give a good response. Conveying uncertainty is always allowed when unsure.
- During Q&A, ask **one question at a time**; do not bundle decisions in one question. Update the relevant issue and affected maintained documents whenever an open point is resolved; do not leave agreed decisions only in chat.
- Discuss each feature into an actionable user story. Put functional/technical specifications and BDD acceptance scenarios in a GitHub issue; obtain approval before production code.
- Work in end-to-end-testable **vertical slices**, one feature branch and one issue-linked PR per slice. Do not deliver disconnected layers as completed features.
- Define BDD scenarios first; implement incrementally with TDD: failing test → minimum code → refactor. See the testing strategy for test boundaries.
- Update `docs/` with code, covering both implementation and rationale; record significant architectural choices in ADRs.
- Every UI-touching feature requires launch of the actual target app, interaction, screenshot capture and visual inspection, with embedded PR evidence. Follow [visual verification](docs/development/testing.md#visually-verify-every-ui-change).
- Discover tooling through the first approved feature; agree material choices as needed and standardize after practical validation. The agent prepares/tests/documents/opens the PR; the owner reviews, approves and merges. See [workflow](docs/development/workflow.md).
- For issue #1, verify prerequisites in the approved order before finalizing dependent production specifications; see the [validation handoff](docs/development/validation-handoff.md). Approve probe scope separately; task-order approval does not authorize execution.
- Hardware-dependent work is **implemented but awaiting hardware validation** until successfully tested on the owner's camera on the agreed target desktop (Pop!_OS 22.04 for issue #1). Fakes do not prove hardware compatibility.
- Report checks actually run, failures, assumptions and limitations. Never invent successful tests or camera access.
- The initial documentation-only scaffold is explicitly exempt from creating an issue; this is not a blanket exemption for future work.

## Boundaries

- Keep domain/application independent of UI frameworks, BLE/Wi-Fi libraries and platform storage. Dependencies point inward; wire adapters at the composition root.
- Add ports/adapters only when a slice needs them. Do not generate speculative frameworks, unused interfaces or platform stubs.
- Before camera pairing, obtain approval: a new pairing may replace the stored one. Do not reset, flash firmware, delete camera files or change camera settings without explicit authorization.
- Keep credentials, personal media, proprietary APKs/firmware, decompiled vendor code and downloaded analysis tools out of git. Use ignored `research-artifacts/` for local research material.
- Treat external source claims as attributed evidence, not our test results. Check licenses before copying community code; archive availability is not a redistribution license.
- Do not silently select plugins, a BDD runner, a state-management library, SDK versions, a project license or browser support. Resolve material choices through the issue/decision process.
- Do not create issues, push or merge merely because a template exists. Follow the user's authorization and report unavailable GitHub access.

## Navigation

| Need | File |
| --- | --- |
| Product scope, glossary, unresolved decisions | [docs/context.md](docs/context.md) |
| Contributor entry point | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Issue/branch/PR and completion process | [docs/development/workflow.md](docs/development/workflow.md) |
| Test levels and hardware evidence | [docs/development/testing.md](docs/development/testing.md) |
| Documentation rules | [docs/AGENTS.md](docs/AGENTS.md) |
| Camera protocols and app provenance | [docs/research/README.md](docs/research/README.md) |

## Commands (verified for this scaffold)

| Purpose | Command |
| --- | --- |
| Inspect local changes | git status --short --branch |
| Inspect configured remotes | git remote -v |
| Check tracked working-tree whitespace | git diff --check |

`git diff --check` does not validate untracked files. No build/test/lint commands exist yet. Add and verify them when the first approved implementation establishes the toolchain; do not claim `flutter test` runs in this scaffold.
