## Slice and issue

Linked approved issue: #<!-- issue number -->

<!-- Use one branch and one PR per slice. The issue holds the approved specification, BDD scenarios and UI expectations. The agent prepares the branch, runs checks, updates docs and opens the PR; the owner reviews, approves and merges. This template does not authorize issue creation, pushing or merging. -->

## Behavior delivered

<!-- Summarize the observable outcome and any agreed scope changes. Link renewed agreement in the issue if the specification changed. -->

## Acceptance and test results

<!-- Map issue scenarios to actual results. State what is simulated. List checks not run and why; do not count skipped checks as passes. Discover tools incrementally through the first approved feature, record prerequisites and verified commands, and standardize after practical validation. Link explicit agreement for material tool choices; Flutter/Dart is selected; remaining tool choices need agreement. -->

| Scenario or check | Boundary / environment | Result and evidence |
| --- | --- | --- |
| | | |

## UI verification and screenshot evidence

Status: <!-- Not applicable (no UI change) / Pending (explain blocker) / Checked (evidence below) -->

<!-- Every UI-touching PR requires launching the actual target app (Pop!_OS 22.04 for issue #1), exercising the agreed journey and states, capturing AND visually inspecting screenshots, then fixing problems and repeating affected checks. Component renders or a browser substitute do not verify the target app. Record keyboard/accessibility results separately; screenshots do not prove them. If blocked, report pending rather than passed. -->

<!-- Embed screenshots below using the evidence storage agreed in the issue. For issue #1, store sanitized, inspected images in the repository and embed revision-specific image URLs here; no separate hosting service. Verify the embedded images are visible to reviewers. Identify scenario/state, expected and observed result, tested revision, OS/runtime environment, window size, and real or simulated camera data for each image. Use safe deterministic sample data at external boundaries when needed, not a mock-up in place of the app. Simulations are not hardware proof. Sanitize evidence before publication. -->

Screenshot evidence: <!-- Embed images here, not only file paths or links. -->

Visual findings and fixes/rechecks: <!-- Compare with the approved issue expectations and wireframes, if any. -->

Keyboard/accessibility checks and limitations: <!-- Record actual results against the agreed checks. -->

## Hardware verification

Camera-communication impact: <!-- None (explain why) / Affected (identify behavior and required real-camera checks). Include indirect effects from UI/application changes. -->

Status: <!-- Not applicable (explain why) / Implemented, awaiting hardware validation / Hardware validation failed / Verified on actual target desktop + M1 3.2-int -->

<!-- Hardware-dependent slices remain implemented, awaiting hardware validation until required scenarios succeed on the actual target desktop (Pop!_OS 22.04 for issue #1) + YI M1 firmware 3.2-int. Automated simulations do not establish hardware compatibility. Pop!_OS evidence does not validate Ubuntu 26.04, Android or iOS. Cosmetic changes or other changes without camera-communication impact may merge after applicable checks pass, without new camera validation; explain the impact assessment below. Protocol or camera-communication changes, including indirect UI/application effects and mixed PRs, require successful actual target-desktop + M1 3.2-int validation before merge. Pending or failed hardware validation blocks those PRs. A merge is not hardware proof. -->

<!-- For actual checks: code revision, date, actual OS/version, confirmed camera firmware, preconditions, steps, expected/observed results, and sanitized evidence. Record pending/failed checks and remaining limitations in the issue too. Never expose credentials, pairing tokens, personal photos, or device identifiers. -->

## Documentation and decisions

<!-- Link docs/ changes explaining use, validation and important decisions. Record which documented steps were verified against the running app, with simulated dependencies and untested steps identified. Safe, current, inspected screenshots may illustrate docs; store durable documentation images in the repository and update or remove stale images. -->

## Review checklist

- [ ] The issue records explicit approval before implementation, or this is the explicitly exempt one-off documentation scaffold.
- [ ] This branch and PR contain one vertical slice and link its issue (except the exempt scaffold).
- [ ] BDD scenarios describe observable user/stakeholder behavior and were defined before production code.
- [ ] Tests were automated incrementally: one failing scenario, supporting red/green cycles, then the next scenario (or not applicable to this documentation-only change).
- [ ] Selected UI flows and technical protocol/adapter checks match the issue's validation plan; BDD is not restricted to UI tests.
- [ ] UI screens/states, visual expectations, relevant window sizes and basic keyboard/accessibility checks were agreed in the issue before coding, or no UI is affected.
- [ ] The actual target app was launched and exercised, screenshots were captured and visually inspected, and fixes were rechecked; current evidence is embedded above, or pending checks/blockers are explicit (or no UI is affected).
- [ ] Acceptance results, checks not run, and hardware status are accurate in this PR and the issue.
- [ ] Documentation is updated alongside the change; documented app steps were verified or untested steps are explicit, and durable images are in the repository.

See the [development workflow](https://github.com/cltec/yi-m1-reborn/blob/main/docs/development/workflow.md) and [testing guide](https://github.com/cltec/yi-m1-reborn/blob/main/docs/development/testing.md).
