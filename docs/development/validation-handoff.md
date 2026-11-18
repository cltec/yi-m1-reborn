# Resume issue #1 prerequisite validation

Use this handoff to resume [issue #1](https://github.com/cltec/yi-m1-reborn/issues/1) with the current increment boundaries and earlier readiness evidence.

## Current delivery plan — 2026-11-17

The owner confirmed the issue is validated and approved two delivery increments:

1. [#2 — Connect to the YI M1 on Linux](https://github.com/cltec/yi-m1-reborn/issues/2): scaffold and implement the end-to-end connection, including discovery, explicit Pair, remembered keyring-backed reuse, fresh Wi-Fi credentials, automatic temporary Wi-Fi association, camera-response verification, status and Retry.
2. [#3 — List camera photo filenames in Gallery](https://github.com/cltec/yi-m1-reborn/issues/3): depend on #2's verified connection, then implement complete JPEG/RAW filename listing. No thumbnails, previews or downloads.

Connection validation is part of #2; known-card inventory and photo-list validation belong to #3. Do not wait for photo-list research or final approval of the entire Gallery before scaffolding/developing #2. The earlier V1–V8 plan below is historical and no longer imposes that blanket implementation gate. Keep dependency-ordered checks within the relevant increment, record actual evidence and stop dependent hardware behavior on unexplained results.

## Offline Gallery development approval — 2026-11-18

Camera unavailable. The owner approved starting #3 application/UI development now through application-owned Ports and Adapters and a simulated camera adapter, with real integration last. #1/#3 specifications updated. Existing pairing/storage/network/reachability ports already isolate external systems; add only the connection/session and filename-list capabilities actually needed by Gallery. Do not introduce a speculative all-purpose camera API or expose platform types to the core. Use the same application workflow for simulated and real adapters, selected at composition roots; visibly label the simulated app.

#2 stays open with real Wi-Fi failure undiagnosed. Current baseline: 130 automated tests, four simulated Linux integration tests, clean analysis/format/whitespace. No new camera or system operation is authorized. Real listing wire format, paging/end conditions and timestamp meaning remain unverified; final hardware acceptance/communication merge gates remain. No new dependency/platform/feature scope is selected.

All #2 implementation and earlier documentation edits are still uncommitted on `feat/2-camera-connection`; preserve them and establish a separate #3 branch without mixing issue changes. Offline tracer bullet: simulated verified session → application filename-list capability → Gallery rows, then incremental sorting/loading/empty/error/Retry/loss behavior with levelled diagnostics and fatal unexpected-error reporting.

## Observability correction — 2026-11-18

A joint network-enabled saved-pairing attempt and the owner's single manual Retry failed at the Wi-Fi step. Old output lacked diagnostic cause; no successful camera HTTP/Connected result was established. The real app was stopped. No further hardware test ran during this correction.

Connection and adapters now emit levelled, sanitized stage/outcome/elapsed diagnostics to stderr. Debug detail uses default-off `CAMERA_DEBUG_LOGS`; no logging dependency, telemetry or persistent log file added. Known failures are explicitly classified; unexpected errors propagate to safe reporting and fatal/no-Retry UI instead of generic connection errors. Cleanup preserves original errors. Numeric NetworkManager state/reason and allowlisted error names distinguish activation stages without raw payloads or identifiers. DBus InvalidArgs is unexpected, not normal Retry.

Latest offline results: **130 automated tests pass**, analysis/format/whitespace checks pass; the simulated Linux integration suite is recorded in the connection guide. Simulated unexpected-error UI was launched, keyboard-interacted, resized, captured and inspected at both sizes. See [evidence](evidence/issue-2/README.md). Real Wi-Fi failure root cause remains unknown until another separately approved joint attempt captures diagnostics. No camera semantics, dependency, operation limit, response-size limit or storage-schema constants changed.

Owner-approved policies: disconnect temporary camera network on close/crash (ADR 0004); allow keyring unlock prompt and continue only on successful storage (ADR 0005). Route-conflict protection is deferred to #4, not a blocker for #1/#2/#3. Hardware privacy/cleanup, native unlock/cancel/failure and strict total deadline remain unverified. Next agree one saved-pairing/AP/Wi-Fi/read-only status attempt with diagnostics; do not Pair again or change user profiles/security policy.

## Offline continuation — latest state (2026-11-17)

The owner asked for development while away and deferred real-camera tests until the next joint session. The previous real test app was stopped. No additional camera, host BlueZ, keyring or NetworkManager operation ran.

Implemented behind a new, default-off `CAMERA_NETWORK_APPROVED` gate: `da5 ON` after fresh credentials, temporary NetworkManager activation, source-bound read-only `GetCameraStatus`, Connected only after valid response, failure cleanup and manual Retry. **99 automated tests**, **4 Linux integration tests**, static analysis and whitespace checks pass. Actual Linux simulated connected/progress/error screenshots were captured and inspected at both agreed sizes. No new dependencies/installations, push, commit or PR.

**A real network-enabled run still needs separate joint approval.** The owner deferred competing-route/interface protection to [issue #4](https://github.com/cltec/yi-m1-reborn/issues/4); it does not block #1/#2/#3. Source binding does not guarantee camera Wi-Fi egress under overlapping Ethernet/VPN routes; record the test setup and limitation. The owner approved system keyring unlock prompts and continuation after successful storage access in [ADR 0005](../decisions/0005-keyring-unlock-prompts.md); native unlock/cancel/failure validation remains pending. The owner approved app-exit/crash disconnection in ADR 0004; real close/crash cleanup remains unverified. The operation budget excludes bounded cleanup, so strict wall-clock C3 is not established. Network/agent password persistence and all new Wi-Fi/HTTP hardware behavior remain unverified. See [connection guide](connection.md), [validation blockers](connection-blockers.md), and [accepted ADR](../decisions/0004-camera-network-lifetime.md).

Final source/test SHA-256: `23a908e1d82d04b84b536603be37909d58937ff7f5a3bf584fac87d814b49bf7` (all Dart files under `lib/`, `test/`, `integration_test/`, `test_support/`, sorted relative path plus contents). Base `d0a92cb`, uncommitted working tree.

Next joint session: agree a narrow real Wi-Fi/status validation scope; competing-route protection is deferred to #4, not a prerequisite. Keyring policy is approved: prompt and continue only on successful unlock/storage; cancel/deny/failure stops with a storage error and manual Retry. Network lifetime is approved: disconnect temporary camera Wi-Fi on app close or crash. Update the issue/maintained docs for each decision. Record the actual network setup and deferred competing-route limitation when requesting and reporting the run. Reuse saved pairing; do not pair again or lock the keyring/manipulate profiles without separate approval. Issue #2 stays open; #3 remains blocked.


## Earlier readiness state and evidence

- Documentation/research only. No application, validation probe or project test setup exists.
- Product behavior, stack/library choices and the V1–V8 dependency order are approved. The final production technical specification is **not approved**.
- After publication, the owner approved the V1 **host checks only** on 2026-11-17. These checks ran; see [results and commands](environment.md#approved-v1-host-check-results--2026-11-17). V1 remains incomplete. Installation of `libsecret-1-dev` was subsequently approved and owner-completed after the agent attempt was blocked by sudo. Package status and `pkg-config` verification succeeded; see the [installation verification](environment.md#prerequisite-installation-verified--2026-11-17). Probe code/execution, other installations and camera operations still require separate approval.
- Earlier host inspection is recorded in [environment](environment.md); recheck relevant observations rather than treating them as current. It did not establish camera compatibility.
- On 2026-11-17, after the host checks, the owner reconfirmed that the camera is beside this PC and powered on. This is owner-reported availability, not camera-operation authorization or a verified connection. Existing pairing remains **unknown**: the owner previously did not think one was remembered, but new pairing could replace it.
- On 2026-11-17 the owner confirmed the photos currently on the card are backed up. This is owner-reported, not an independently checked backup. The owner does not know whether the card contains both JPEG and RAW photos. Test-card inventory and file-type coverage remain pending; do not assume either format is present. Do not prepare the card by deleting files or changing camera settings.

## Earlier dependency order — superseded by the two-increment plan

The issue holds task acceptance/evidence details. None of these validation tasks is complete.

| Task | Depends on | Result needed |
| --- | --- | --- |
| V1 — Safe validation setup | None | Approved procedure, relevant tools/access, safe camera/card preconditions and separately approved minimal probes |
| V2 — Camera discovery/GATT | V1 | Actual identifiers and required capabilities, without pairing or camera Wi-Fi activation |
| V3 — Authorized pairing/session | V2 | Camera approval and verified session; retain required pairing material privately in the keyring |
| V4 — Remembered reuse/fresh credentials | V3 | Reuse without new pairing; verify needed identity/key/token and retrieve current Wi-Fi credentials |
| V5 — Automatic Wi-Fi/reachability | V4 | Association, routing, temporary profile lifecycle and no separately persisted Wi-Fi password |
| V6 — Read-only photo-list behavior | V5 | Known-card evidence for requests, pagination, JPEG/RAW representation and timestamps |
| V7 — Final production specification | V1–V6 | Evidence-backed contracts, fixtures and validation plan; explicit owner approval |
| V8 — Gallery implementation/acceptance | V7 | Incremental BDD/TDD, actual UI checks and end-to-end hardware evidence |

A failed or pending prerequisite blocks dependent work. Research and fakes may inform probes, but do not satisfy these checks. Earlier probe success does not replace acceptance of the final production integration. All camera operations remain subject to [safety boundaries](../research/device-validation.md#safety-boundaries).

## Earlier fresh-session procedure — historical scope

1. Read root/scoped agent rules, [context](../context.md), [workflow](workflow.md), [testing](testing.md), [architecture](../architecture/README.md), ADRs and issue #1 including comments. Check `git status --short --branch` before editing.
2. Confirm that this is still the target PC/camera setup. Ask one question at a time. Do not infer permission from camera availability or earlier product decisions.
3. Review the recorded approved host-check results before proposing any repeat checks; do not infer permission for new operations.
4. Review the verified `libsecret-1-dev` installation and unresolved card inventory/pairing preconditions. Do not mark V1 complete from tool availability alone.
5. Prepare the smallest separately reviewable probe proposal. Stop for authorization before writing/executing probe code, installing prerequisites, scanning, pairing, joining Wi-Fi or exercising keyring writes. Do not proceed to V2 until V1's required readiness evidence is satisfied.
6. Update issue #1 and affected docs with results, limitations and the next blocked/ready task. Do not finalize the Gallery production specification before V1–V6 evidence.

## V1 host-check scope and remaining preparation

The host checks below were approved and executed on 2026-11-17; [environment results](environment.md#approved-v1-host-check-results--2026-11-17) record actual observations. Camera/card confirmation and probe preparation remain pending:

- Recheck pinned Flutter/Dart availability, Linux build prerequisites, active BlueZ/NetworkManager services and current authorization. Prior inspection commands and versions are in the environment record. Run Flutter diagnostics sequentially to avoid its startup-lock contention; diagnostics may refresh SDK caches or contact services, but must not upgrade/configure the SDK or alter desktop settings.
- Use version queries, package inventory, service/property reads and permission queries. Do not enumerate unrelated saved profiles, request secrets, scan, restart services, change radio state, switch networks or modify authorization policy.
- Recheck only whether Secret Service is present, not whether personal secrets can be read. The previously missing `libsecret-1-dev` was installed under separate approval and verified; this does not validate the plugin or authorize other installations. Keyring read/write and locked/unavailable tests need a separate approved, safely scoped probe.
- Ask about existing pairing and safe known card contents/backups. Record uncertainty. No need to disclose photos, passwords, tokens, device addresses or serial numbers.
- Propose a minimal validation workspace and exact probe scope/commands, prerequisites and expected outcomes. No new dependencies, project scaffolding, UI implementation or production adapters in this read-only pass.

Output: a sanitized readiness report separating observed results, missing prerequisites, unresolved preconditions and the next approval request. V1 remains pending until its required setup/probe evidence is complete.

## New-session starting prompt

> Resume the owner-approved two-increment plan for issue #1. Start with #2, the Linux Flutter camera-connection increment; #3 adds photo filenames only after the connection works. Read the current issues and docs/context.md. Earlier host checks and the approved libsecret-1-dev installation are verified, but camera/keyring behavior is not. Scaffold/develop #2 incrementally with BDD/TDD and validate its connection prerequisites in order; photo-list research does not block it. Preserve existing documentation edits. Obtain scoped approval before probes, other installations or hardware operations, and explicit approval immediately before pairing. Record actual checks, limitations and safe evidence in the issue and docs.

## Pairing implementation — 2026-11-17

The owner approved implementing the pairing flow before more camera tests. The application now requires explicit Pair after selection, preflights GATT and protocol-1 firmware, requests approval once, handles refusal, persists approved identity/reference/token through an application-owned keyring port with immediate read-back, and resumes a BLE session to read fresh Wi-Fi credentials privately. No Wi-Fi activation or association exists yet. These wire/identity choices are sourced assumptions, not this camera's measured behavior.

The same pairing/session attempt has a 120-second operation budget; cleanup is best effort, bounded to one second per resource and can extend settlement past the budget. Overlapping attempts are rejected and Retry waits for old cleanup. Pending accepted material survives save failure in memory; Retry tries storage/session without another pairing. Cancellation does not undo already-issued OS calls. The full discovery-to-network deadline is not yet implemented.

`flutter test` now passes **54 tests** (application, widgets, isolated BlueZ/D-Bus and mocked keyring channel), and `flutter analyze` passes. No host keyring or real-camera pairing/session operation has run. Pair UI and waiting-for-approval were exercised in the actual Linux app with simulated boundaries; screenshots were captured and inspected. Current complete-connection acceptance remains incomplete.

Selected plugin limitation: Linux secure-storage may request keyring unlock and continue if unlocked, rather than immediately fail on an initially locked collection. LinuxOptions cannot disable that prompt. At that inspection, stop-on-locked acceptance was unresolved. The owner subsequently approved prompt-and-continue in [ADR 0005](../decisions/0005-keyring-unlock-prompts.md); mocked KeyringLocked translation still does not prove native unlock/cancel/failure behavior. Immediate read-back catches missing/stale native writes but does not prove restart persistence. No new dependencies were selected.

Next: complete simulated-boundary verification/review, then request explicit approval for one joint pairing/keyring/session run. No separate camera test is required before coding. Pairing can replace an existing registration; no pairing flag is standing approval. Wi-Fi activation/join, HTTP reachability and media access remain excluded from that prepared pairing run.

## Latest joint test — BLE session result

On 2026-11-17, the owner authorized the real pairing-enabled run. The user screenshot and an independently captured/inspected app window show BLE-session success. First-pair versus remembered-reuse branch, camera-screen confirmation and keyring prompts still need owner confirmation; restart persistence is not yet tested. No Wi-Fi activation/association, HTTP or media operation ran. See [evidence and limits](evidence/issue-2/README.md#joint-ble-session-result--2026-11-17). The next question is whether the owner pressed Pair and approved on the camera; do not initiate a new pairing to resolve that uncertainty.

## Owner confirmation — first Pair, failure, then Retry

The owner confirmed selecting **Pair** and approving the request on the camera screen during the joint 2026-11-17 run. The first app attempt failed; after the owner pressed **Retry**, the app reached the previously captured BLE-session success screen. This confirms actual user-authorized new pairing was initiated and camera-screen approval occurred. The successful Retry is consistent with storage/session recovery without a fresh pairing, but the first error and whether a second camera approval occurred have not been established. Do not infer the failed step, root cause, absence of repeated pairing, or uninterrupted first-attempt success from the final screenshot. Preserve the initial failure as part of the hardware evidence. Restart persistence, Wi-Fi and HTTP acceptance remain pending. No additional camera action was initiated by the agent while collecting this account.

Next question: what exact error appeared on the first attempt? Do not reproduce the failure by pairing again merely to obtain the message.

## Remembered restart test — failed at camera lookup

On 2026-11-17, the owner approved restarting only to verify saved pairing reuse, without a new Pair action or Wi-Fi changes. The agent stopped the previous app and launched the pairing-enabled app again. No Pair or Retry was pressed by the agent. Observed error: **“Camera session failed while finding the selected camera. Select Retry to reuse the remembered pairing.”** The actual app screenshot was captured and visually inspected: [restart lookup failure](evidence/issue-2/real-restart-lookup-failure.png). No identifiers/secrets displayed.

**Outcome: restart reconnection failed.** The stage proves the app read and decoded a remembered record through the app keyring on the new process and entered `resume`, but did not resolve exactly one matching cached BlueZ device. It does not prove invalid pairing or an expired token. No new-pairing write or camera session write was issued on this failed path. Wi-Fi remained unchanged. The earlier first-attempt failure's cause is still unknown; the owner cannot recall its message. Do not claim it had this same cause.

Source inspection: current resume lookup requires stored address, address type and M1 UUID on the BlueZ cache, without rediscovery. Possible causes include a missing cached device/service, identity change, or camera availability; no raw cache/secret inspection or further hardware test ran to choose among them. Offline diagnosis/regression work follows before requesting another joint run. C2 automatic reconnect remains failed/pending, not passed. App-keyring record survival across this process restart is observed; locked/unavailable behavior remains unverified.

## Remembered lookup correction — hardware retest pending

Offline regression tests reproduced two lookup weaknesses: remembered devices with absent cached service UUIDs were rejected before GATT access, and an absent cached device was never rediscovered. These reproduce plausible mechanisms for the observed lookup failure, not a proven diagnosis of the actual camera state.

Resume now matches the exact stored address/address type without relying on advertised UUIDs, then validates the exact M1 GATT service plus session/credential capabilities before any session write. If no exact cached identity exists, it performs one filtered LE rediscovery window (up to 10 seconds, within the remaining 120-second operation budget) on the first powered adapter. It still accepts only the exact stored identity, never another candidate; ambiguous matches, changed random identity or unsupported GATT fail closed. Only its owned scan/client is released. No new pairing or keyring record replacement is a fallback. This changes reconnect discovery behavior; another real-camera test needs the owner's approval.

Five regression checks cover missing cached UUIDs, rediscovery success, non-M1 GATT before writes, no matching rediscovery and cancellation cleanup. The full automated suite now passes **59 tests**; static analysis is clean. The 3 existing Linux integration tests passed before this adapter-only correction; they use simulated pairing and do not prove the new real lookup behavior. The original real restart failure remains recorded. Hardware retest is **pending**; no further host/camera operation ran during the offline fix.

## Remembered BLE restart retest — succeeded

On 2026-11-17, an owner-approved fresh app launch with the lookup correction reused saved pairing and reached BLE-session success without Pair or Retry. The owner confirmed the displayed result. See the [retest evidence](evidence/issue-2/README.md#remembered-restart-retest--ble-session-succeeded-2026-11-17). This verifies process-restart persistence and BLE-session reuse in this run, not camera-power-cycle recovery or the optional rediscovery branch. Wi-Fi/HTTP and full C2 acceptance remain incomplete; locked-keyring behavior remains unresolved. Earlier failures above are historical evidence, not the latest retest outcome.
