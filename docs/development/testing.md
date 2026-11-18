# Validate a vertical slice with BDD and incremental TDD

Use this guide when implementing an approved slice issue. It assumes the story, scope, and acceptance scenarios are agreed through the [development workflow](workflow.md).

Flutter 3.44.4 with bundled Dart 3.12.2 is pinned for issue #1. The owner approved standard Flutter test tooling for BDD: `flutter_test` for application behavior and widget tests, plus SDK `integration_test` for selected running-app flows. No separate Gherkin runner or feature-file generator is selected. `flutter test` and `flutter analyze` now run from the repository root; the [connection guide](connection.md) records current checks and desktop validation results. The first target environment is Pop!_OS 22.04 LTS (Ubuntu 22.04-based), as agreed in [issue #1](https://github.com/cltec/yi-m1-reborn/issues/1). Discover suitable tools through the first approved feature, agree material choices in its issue as they arise, and standardize after they work in practice. The setup must support launching the target application, interacting with it, capturing screenshots and inspecting them. Record decisions, prerequisites and verified commands; do not treat illustrative commands as an existing test setup.

## Define behavior before production code

Write Given/When/Then scenarios in the issue before implementing the slice:

- **Given:** the relevant user-visible starting state and conditions.
- **When:** the user or stakeholder takes an action, or an external event occurs.
- **Then:** the observable outcome that proves the agreed behavior.

Scenarios specify user or stakeholder behavior, not class names, private methods, mock calls, or an internal sequence of functions. Agree which success, failure, and recovery cases matter for this slice rather than adding speculative cases.

For example, a proposed download slice might have this scenario; it is not a claim that downloads already work:

> **Given** the user is connected to the camera and selects an original photo,
>
> **When** the user downloads that photo,
>
> **Then** the saved file is available at the agreed destination and matches the selected original unchanged.

The issue must settle the destination, supported file types, and verification method before that scenario is ready for implementation.

## Use standard Flutter tooling for BDD

For issue #1, keep the agreed Given/When/Then scenarios in the issue and automate them as named Dart tests through public boundaries. Map issue scenario numbers/titles to the relevant tests and results so that behavior changes update both the specification and its checks. Given/When/Then structure alone is not sufficient: assertions must establish the agreed observable outcomes.

Use `flutter_test` for behavior-level application tests and widget tests, with small fakes at external ports where needed. Use SDK `integration_test` for selected journeys in the actual Linux app. Both come from the pinned Flutter SDK; this choice does not introduce a separate Gherkin runner, `.feature` generator or third-party BDD framework. Add and run one scenario incrementally before expanding coverage.

The standard tools do not cover every external boundary:

- `integration_test` does not drive native OS dialogs. For issue #1, the owner approved manual checks of native keyring and OS authorization dialogs on the target PC, alongside automated app tests; do not add a desktop automation framework for this slice. Record prompts actually encountered, actions, expected/observed outcomes, and checks not run. For the owner-approved [keyring policy](../decisions/0005-keyring-unlock-prompts.md), verify successful unlock continues the same attempt, while canceled/denied/failed unlock and unavailable/failed storage stop with a storage error and manual Retry. Check these paths only under separately approved scope, without changing host security policy. If the current session needs no prompt, record that rather than claiming a dialog was tested. Simulated permission results are not real OS verification. All actual native-dialog checks remain pending.
- The installed Flutter 3.44.4 `integration_test` README documents its screenshot API for Android, iOS and web, not Linux. For issue #1, use the installed ImageMagick `import` tool to capture only the actual Linux app window, then visually inspect each image before publication. App-window capture and visual inspection now cover simulated camera selection; see the [connection guide](connection.md).
- Passing tests with fake BLE/network/storage ports do not prove the target camera, NetworkManager or keyring integration.

References inspected on 2026-11-17: [Flutter testing overview](https://docs.flutter.dev/testing/overview), [integration-test guide](https://docs.flutter.dev/testing/integration-tests), and the installed pinned SDK's `packages/integration_test/README.md`. Current online documentation can describe a newer Flutter release; confirm behavior on the pinned SDK. The initial target-desktop build failure is resolved. The current automated suite covers application, widget, isolated D-Bus and local HTTP behavior; four Linux integration journeys pass with simulated external boundaries. See the connection guide for current counts. Real saved BLE-session reuse passed; full Wi-Fi/HTTP camera verification remains pending.

## Choose the right test boundary

BDD does not require every scenario to run through a UI. Choose the smallest public boundary that can prove the behavior without hiding the integration risk.

| Check | Use it to establish | Limit |
| --- | --- | --- |
| Selected UI end-to-end flows | Critical user journeys across the application | Do not duplicate every case through the UI |
| Visual inspection of the running target application | Screens and states match agreed visual expectations | Required for every UI-touching feature; screenshots alone do not prove functional or camera behavior |
| Behavior-level integration tests through public interfaces | Observable outcomes and failure/recovery rules | Avoid coupling tests to private implementation details |
| Technical protocol/adapter tests | Request/response handling, parsing, transport behavior, and external integration contracts | These complement BDD; they are not all user acceptance scenarios |
| Actual target desktop + YI M1 3.2-int checks | Behavior with the target OS, camera, and firmware | Required for hardware-dependent acceptance; simulations are not a substitute |

Use test doubles at external boundaries when needed for repeatable automated checks. State what is simulated and what is real. A fixture based on research is an assumption until checked against hardware; its passing test must not be reported as camera verification. For parent issue #1, the owner approved connection first (#2), then filename listing (#3). Validate prerequisites within each increment before relying on them as proven contracts: connection discovery/session/storage/network checks in #2, known-card listing/pagination checks in #3. Photo-list research does not block scaffolding or developing the connection increment. Stop dependent hardware behavior at failed or pending prerequisites; fakes do not substitute for camera/platform evidence. Approve narrow probes separately and use verified observations to inform production tests. Executing probes and pairing still needs the applicable approvals.

## Automate and implement incrementally

1. Select one agreed acceptance scenario. Automate it at the chosen boundary.
2. Run it and observe the expected failure for missing behavior. A broken test setup is not evidence that the behavior is missing.
3. Where supporting logic needs a narrower check, add one failing test through a public interface.
4. Add the minimum production code to pass the current supporting test. Repeat this red/green cycle as needed until the acceptance scenario passes.
5. Refactor only while tests pass, and rerun affected checks after each change.
6. Select the next scenario and repeat. Run the relevant regression checks before the PR is ready for review.

Define scenarios up front, but do not write all automated acceptance and supporting tests before writing any production code. Learn from each working increment. Prefer tests that survive internal refactoring because the observable behavior has not changed.

## Visually verify every UI change

Before coding, agree affected screens, important states and visual expectations in the issue, with simple wireframes where useful. For issue #1, the approved Gallery layout has a title/status area above the filename list; loading, empty and error states use the same content area, with Retry on errors and no sidebar or extra navigation. First-time setup uses the same Gallery content area for discovered cameras; the user selects one and presses **Pair** to authorize initiating pairing. Check that selection alone does not pair, that no camera can pair without a selection, and that camera-side approval remains required. Use the approved initial desktop window size of **1000 × 700 logical pixels** and validate layouts down to **640 × 480 logical pixels**, including camera selection, loading, populated, empty and error states. Check for clipping, overlap and inaccessible controls at both sizes. These are design/check sizes, not an approved enforced minimum-size constraint. Record the actual capture dimensions and display scale alongside logical window size. Validate these states in the running app. Discovery/selection, progress, connected-only and error layouts are implemented; filename-list states belong to #3. Connected-only screenshots use simulated network/HTTP results, not hardware proof. Select relevant loading, empty, success and error states, window sizes, and basic keyboard/accessibility checks for this slice. For issue #1, verify keyboard-only camera selection and activation of **Pair** and **Retry**, visible keyboard focus, and text identifying connection status rather than relying on color alone. Connection increment #2 covers camera selection, progress, connected and connection-error states; listing increment #3 adds loading, populated, empty and listing-error states. The connected-only state must not imply an empty or already-read card. Exercise these checks in the actual target app at the approved window sizes; widget checks can support but do not replace running-app verification. Screenshots cannot prove keyboard interaction or all accessibility behavior; exercise those checks separately. These checks do not constitute a full accessibility audit or screen-reader compatibility claim.

For each feature that touches the UI:

1. Launch the actual application on the target platform, initially Pop!_OS 22.04. Exercise the agreed user journey rather than relying only on component renders or source inspection.
2. Reach the agreed states and capture screenshots at the selected window sizes. For issue #1, use ImageMagick `import` for app-window-only capture in the target X11 session; exclude unrelated desktop windows and inspect every image before publication. Verify the actual capture command when the app exists; `import -version` established tool availability, not capture success. Use deterministic safe sample data through external-boundary fakes when needed for repeatability. Do not replace the UI or application workflow with a screenshot mock-up.
3. Open and visually inspect each screenshot against the issue's expectations. Check the agreed layout, text, controls and state feedback for visible problems such as clipping, overlap or unreadable content. Merely saving an image is not verification.
4. Fix problems and repeat the affected functional and visual checks. Capture current evidence after the fixes; rerun affected checks if later edits change the inspected UI.
5. Embed screenshots in the PR with captions identifying the scenario/state, expected and observed result, tested code revision, OS/runtime environment, window size, and whether camera data was simulated or real. Record visual findings, keyboard/accessibility results and any remaining limitations.

For issue #1, store sanitized, visually inspected screenshot evidence in the repository and embed the images in the PR, without a separate hosting service. Use revision-specific repository image URLs in the PR so evidence stays tied to the tested revision, and verify that reviewers can see the embedded images. Include only the required safe app-window evidence, not unrelated desktop captures, credentials or personal media. Local inspected selection screenshots are in `docs/development/evidence/issue-2/`; publication and revision-specific PR embedding remain pending. Other slices should record their evidence location in their validation plan. If the application cannot be launched, exercised, captured or inspected, record the blocker and pending checks. Tooling discovery is not a substitute for this evidence, including on the first UI feature.

Screenshots complement functional tests. A correct-looking gallery does not prove camera communication, and a download confirmation does not prove original-byte integrity. Simulated camera data does not establish real-camera compatibility.

### Reuse screenshots in documentation

Use inspected screenshots from the tested application when they help explain the feature. Keep durable documentation images in the repository, link them with relative paths and descriptive alternative text, and include useful captions. Use safe sample media and sanitize secrets, personal paths, device identifiers and other private content before publication. Clearly identify simulated data without presenting it as hardware evidence.

Keep images consistent with the documented UI; update or remove them when affected behavior changes. Keep written instructions usable without the images. Verify the documented steps against the running application and report any parts not exercised. Historical PR evidence describes the tested revision; maintained documentation describes current implemented behavior.

## Record results and hardware limits

For each acceptance scenario, record whether it is automated, manually checked, pending, or failed, with the actual result and evidence. List checks not run and why. Report a skipped or unavailable hardware check as pending, never passed.

For real-hardware verification, record:

- The issue/scenario and code revision tested.
- Actual OS/version (Pop!_OS 22.04 for issue #1), actual YI M1 body, and confirmed firmware version **3.2-int**.
- Preconditions, actions, and expected and observed results.
- Check date, pass/fail outcome, and sanitized evidence sufficient to repeat the check.
- Remaining limitations, including platform checks not performed.

Use the [device-validation safety guidance](../research/device-validation.md) when planning camera checks. Obtain approval before pairing or changing settings. Do not publish credentials, pairing tokens, personal photos, or device identifiers in test evidence. Do not update or downgrade firmware just to satisfy a test without explicit approval.

A hardware-dependent slice can be implemented with repeatable automated checks while camera access is unavailable once its prerequisite facts and production specification are established. For issue #1, the owner-approved two-increment plan supersedes the earlier blanket V1–V7 gate: develop and validate connection in #2, then photo filenames in #3. Neither increment may claim unverified protocol assumptions as hardware evidence. Keep its status **implemented, awaiting hardware validation** until its required real target-desktop + M1 3.2-int scenarios succeed. Then record that evidence in the issue and PR. Protocol or camera-communication changes cannot merge while their required hardware validation is pending or failed. Cosmetic changes and other changes without communication impact may merge after applicable checks pass, without new hardware validation; record why it is not required for that change. Assess indirect behavioral effects, not just the files edited, as described in the [workflow](workflow.md#5-report-completion-honestly). Pop!_OS success does not establish Ubuntu 26.04, Android or iOS support.
