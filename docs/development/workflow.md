# Deliver a feature as a vertical slice

Use this guide to take an agreed behavior from discussion to an issue-linked pull request (PR). It assumes familiarity with Git, GitHub issues, and tests.

The first target for [issue #1](https://github.com/cltec/yi-m1-reborn/issues/1) is Pop!_OS 22.04 LTS, with Android/iOS later. [Project context](../context.md) records approved product and tool choices; [environment](environment.md) separates measured prerequisites from untested integrations. Use the [validation handoff](validation-handoff.md) to resume the approved prerequisite order. Discover remaining tools incrementally, agree material choices and standardize after practical validation. Record actual prerequisites and verified commands; tooling discovery does not waive functional, hardware or visual checks.

## 1. Agree on the user story

Discuss the feature **one question at a time**. Resolve the next uncertainty before moving to another question. Update the relevant issue and affected maintained documents whenever a point is agreed; do not leave decisions only in chat. Confirm the user, their goal, the observable benefit, and the limits of the feature.

Write an actionable story:

> As a [user or stakeholder], I want [capability], so that [outcome].

Keep the slice small enough to implement and test end to end. It must deliver an observable outcome across the needed layers, rather than only a database, protocol client, or screen. Leave unrelated work out.

## 2. Prepare and approve the GitHub issue

Create the issue using the [feature template](../../.github/ISSUE_TEMPLATE/feature.yml) as the specification checklist. The GitHub web form or an authorized agent/CLI may create it; the template does not create or approve issues automatically.

The issue is the agreed specification. Include:

- The story, functional behavior, scope, and explicit exclusions.
- A technical plan: interfaces involved, integration approach, constraints, risks, and unresolved decisions.
- BDD acceptance scenarios in Given/When/Then form, including agreed failure or recovery behavior.
- The validation plan: selected UI end-to-end flows, other behavior-level tests, technical protocol/adapter tests, and any real-hardware checks.
- For UI changes, expected screens, important states and visual expectations, using simple wireframes where useful. Agree relevant loading, empty, success and error states, window sizes, and basic keyboard/accessibility checks rather than an undefined test matrix. Plan repeatable sample data at external boundaries where needed.
- The documentation readers need: a task guide, reference or explanation of the slice and its important decisions. Identify the steps to verify in the running application and any useful screenshots.
- Where screenshot evidence will remain accessible; embed it in the PR. For issue #1, store sanitized, inspected screenshots in the repository, without a separate hosting service. Keep durable documentation images in the repository too.

When behavior depends on unverified camera/platform facts, validate the prerequisites before relying on them as production contracts. The owner approved splitting issue #1 into [connection #2](https://github.com/cltec/yi-m1-reborn/issues/2) and then [filename listing #3](https://github.com/cltec/yi-m1-reborn/issues/3). Scaffold and develop the connection increment with its own dependency-ordered checks: readiness → discovery/GATT → authorized pairing/session → remembered reuse/fresh credentials → Wi-Fi/reachability. Photo-list validation belongs to #3 and does not block #2. This supersedes the earlier all-Gallery V1–V7 gate before any implementation. Record measured contracts and limitations as each increment proceeds; do not treat unverified protocol assumptions as observed facts. Readiness checks precede camera operations; probes/installations need their applicable approval, and pairing requires explicit authorization. Each increment remains a complete, independently verifiable behavior, not a disconnected application layer. On 2026-11-18 the owner approved offline #3 application/UI development through application-owned ports and simulated outbound adapters while the camera is unavailable, before #2 hardware completion. Keep the real adapters and connection rules behind those boundaries. Real connection/listing integration and affected hardware validation move to the final stage and remain required before completing or merging camera-dependent behavior.

Resolve blocking questions and record explicit approval of the specification in the issue before implementation starts. A filled template or a checked box is not approval. If the scope or acceptance behavior changes, update the issue and obtain agreement before implementing the change.

**Exception:** this one-off repository documentation scaffold is explicitly exempt from the issue requirement. The exception does not apply to later feature slices.

## 3. Implement one slice on one branch

Create one branch and one PR for the approved slice. Link the issue in the PR. Do not combine independent slice issues into the same branch or PR.

Define the acceptance scenarios before production code, then follow the [incremental BDD and TDD workflow](testing.md):

1. Automate one acceptance scenario and confirm that it fails for the expected missing behavior.
2. Add one supporting failing test where needed; implement only enough behavior to pass it.
3. Repeat small red/green cycles until the acceptance scenario passes.
4. Refactor with passing tests, then select the next agreed scenario.

Do not write all tests in bulk before implementation. Keep the slice end-to-end testable even when some checks need hardware that is not yet available.

Update `docs/` alongside the code. Explain how to use or validate the behavior and why important design decisions were made. Verify documented user steps against the running application, stating any simulated dependencies or unavailable checks. Link relevant research instead of turning unverified findings into product guarantees. Follow the [screenshot guidance](testing.md#visually-verify-every-ui-change) when illustrating docs.

### Observability and error handling

Include diagnostics in the slice, not only after a failure. Log essential operation starts, stages and outcomes at info level; recoverable/degraded conditions at warning; failures at error; and development-only details at debug/trace. Include elapsed time and safe cause/reason codes so a failed attempt can be followed without repeating it blindly. Keep credentials, tokens, SSIDs, device identifiers and raw potentially sensitive payloads out of logs. Do not assume exception messages or stacks are safe to publish without review.

Handle only known failures that the boundary can recover from or translate. Preserve safe causal context and stack information. Unexpected/programming errors must fail fast and remain visible to error reporting, not become a generic connection failure or Retry loop. Always release owned resources, but do not let cleanup failures mask the original failure; report cleanup outcomes separately.

Test meaningful diagnostic events/levels and secret exclusion at the relevant boundary. Verify that managed failures are translated and unexpected errors remain observable. Do not select a logging dependency, external telemetry service or persistent-log storage policy without the normal issue approval process.

## 4. Verify and open the PR

The implementing agent prepares the branch, runs checks, updates documentation and opens the issue-linked PR. The owner reviews, approves and merges it; the agent does not approve or merge its own work. This division of responsibility does not by itself authorize creating issues or pushing changes. Obtain the necessary authorization and report unavailable GitHub access.

For every feature touching the UI, launch the actual application on the target platform (Pop!_OS 22.04 for issue #1), exercise the agreed journey and states, then capture and inspect screenshots. Fix visible problems and repeat the checks before requesting review. Isolated component renders or browser substitutes do not establish that the target desktop application works. If launch, interaction, capture or inspection is blocked, report visual verification as pending rather than passed.

Use the [PR template](../../.github/pull_request_template.md) to record:

- The linked issue and implemented behavior.
- Acceptance scenarios covered, checks actually run, outcomes, and checks not run.
- Documentation changes and relevant design decisions, including verified user steps.
- For UI changes, embedded screenshots and visual findings mapped to agreed expectations. Captions identify scenario/state, expected and observed result, tested revision, environment/window size, and real or simulated camera data.
- Hardware verification status and supporting evidence.

Follow the [testing guide](testing.md) for evidence requirements. Automated checks with simulated devices do not prove camera compatibility. Review the actual changes against the approved issue, not only the checkbox list.

## 5. Report completion honestly

For a slice that requires a camera, report **implemented, awaiting hardware validation** until the required checks succeed on the actual target desktop with the YI M1 running firmware **3.2-int**. Record successful hardware evidence in the issue and PR before calling that acceptance verified.

If hardware validation fails, record the observed result and remaining work in the issue. Do not replace the failure with a simulated pass or describe the slice as fully validated. Evidence from Pop!_OS does not validate Ubuntu 26.04, Android or iOS.

Keep implementation status separate from acceptance and hardware verification status. Before owner approval and merge, assess camera-communication impact in the issue and PR:

- Cosmetic changes and other changes that do not affect camera communication may merge without new real-camera validation once their applicable functional, visual and documentation checks pass. Explain why camera validation is not required for the change; do not claim this validates previously unverified camera behavior.
- Changes that affect the protocol or camera communication require successful validation of the affected behavior on the actual target desktop (Pop!_OS 22.04 for issue #1) + YI M1 firmware **3.2-int**, with evidence in the issue and PR, before merge. Pending or failed hardware validation blocks merge.

Assess behavior, not only file location: a UI or application change that alters camera commands, connection sequencing or communication behavior belongs in the second category. Mixed PRs must satisfy that requirement too. A merge does not by itself establish hardware compatibility.
