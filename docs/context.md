# Project context

## Identity and current state

**YI M1 Reborn** is a replacement companion application for the Xiaoyi / YI M1 Micro Four Thirds mirrorless camera. Repository: [cltec/yi-m1-reborn](https://github.com/cltec/yi-m1-reborn), SSH `git@github.com:cltec/yi-m1-reborn.git`.

The owner confirmed camera firmware **3.2-int** and a computer with Bluetooth and Wi-Fi. The first target is this PC running **Pop!_OS 22.04 LTS**, based on Ubuntu 22.04, as measured from `/etc/os-release` on 2026-11-17 and approved by the owner. The firmware version is owner-confirmed. Joint tests have verified BLE-session setup and saved-pairing reuse across an app restart, not full Wi-Fi/HTTP connection.

Current state: Linux Flutter connection implementation in progress for issue #2. Explicit pairing, app-keyring storage and remembered BLE-session reuse exist; Wi-Fi/reachability is implemented behind a default-off execution gate and passes simulated-boundary tests (130 automated, 4 Linux integration). Real BLE restart reuse passed; full connection and network privacy acceptance remain pending. Offline #3 Gallery development now uses application-owned connection/session and complete-catalog ports, a shared listing use case, and a visibly simulated entry point; real filename wire parsing/pagination remains final integration work. There is no CI pipeline. Desktop integration testing initially failed before launch because Clang selected GCC 12 without its C++ development library. The owner installed `libstdc++-12-dev`; verification and the clean-build Linux integration test succeeded. Keyboard selection was tested with simulated discovery, not the camera. See the [connection guide](development/connection.md). No third-party application fork exists.

The owner requested a combined development snapshot and draft PR, with remaining work split into linked sub-issues #5–#13. See [remaining work](development/remaining-work.md). #1/#2/#3 remain open; this is not a completed or merge-ready camera integration.

## Confirmed product scope

| Area | Agreed behavior |
| --- | --- |
| Platforms | Linux desktop first: Pop!_OS 22.04 LTS on the owner’s PC; Android and iOS later. Ubuntu 26.04 remains unverified. |
| Connection | Selecting Gallery or Live connects automatically to the remembered camera; prompt for pairing only when needed. Connection status and manual Disconnect are part of the agreed connection experience. |
| Gallery | Show thumbnails of camera images; open a larger preview; download selected original JPEG and RAW files. |
| Live | Display the camera's live video feed and allow a remote photo shot. |
| Remote shot destination | Save on the camera only; do not automatically download the resulting photo. |
| Architecture | Ports and Adapters, with platform-independent domain/application and platform-specific I/O adapters. Flutter/Dart is selected for the application. |
| Delivery | End-to-end-testable vertical slices, BDD acceptance criteria and incremental TDD. |

RAW support includes browsing/downloading originals. It does **not** yet promise full-resolution RAW decoding or a thumbnail for every RAW file; preview behavior and later RAW+JPEG grouping need specification and camera tests.

## Delivery increments: approved, in progress

[Issue #1](https://github.com/cltec/yi-m1-reborn/issues/1) remains the parent specification. On 2026-11-17, the owner confirmed that the issue is validated and approved dividing delivery into two end-to-end increments:

1. [Camera connection — #2](https://github.com/cltec/yi-m1-reborn/issues/2): Linux Flutter scaffold, discovery and explicit Pair, BLE session, keyring-backed remembered reuse, fresh Wi-Fi credentials, automatic temporary Wi-Fi association, a harmless camera-response check, connection status and manual Retry. No photo listing. The connected state must not imply that the card has been read or is empty.
2. [Photo filename listing — #3](https://github.com/cltec/yi-m1-reborn/issues/3): offline application/UI development may proceed through application-owned ports and simulated adapters before #2 hardware completion (owner-approved 2026-11-18). Final real connection/listing integration and hardware acceptance remain required. Reuse the connection capability to list every JPEG/RAW filename with the agreed ordering, loading, empty and error states. The owner explicitly confirmed **filenames only**, not thumbnails or image downloads.

The camera is currently unavailable. The owner approved moving hardware integration/validation to the final stage, not removing it or claiming simulation proves compatibility. Keep real communication behind adapters and the simulated path in the same application workflow. Each increment has one feature branch and issue-linked PR, incremental BDD/TDD, actual Linux UI verification and real-camera acceptance. Connection discovery and validation belong to #2; photo-list validation belongs to #3 and does not block the connection scaffold or implementation. This replaces the earlier requirement to finish V1–V7 for the entire Gallery before starting any production work. Verify unknown connection facts in dependency order as that increment progresses; research and fakes do not establish camera support. Separate probe/installation approvals and explicit approval before pairing or other camera operations remain applicable.

Host-only readiness checks ran on 2026-11-17; see the [environment record](development/environment.md#approved-v1-host-check-results--2026-11-17). The owner approved and completed installation of `libsecret-1-dev`; package status and `pkg-config` checks verify it. The Linux app builds and launches. App-keyring persistence and BLE-session reuse passed a joint restart test; complete Wi-Fi/HTTP connection remains unverified. Camera availability/power and card backups are owner-reported. Card inventory and existing pairing remain unknown; JPEG/RAW coverage is needed for #3, not for the connection increment. The [handoff](development/validation-handoff.md) preserves evidence and safety boundaries.

Existing product and tool decisions remain in force. Development tests simulate external boundaries; the owner requested that real-camera tests be performed together. One owner-approved joint 10-second filtered discovery run returned one matching candidate. Later approved tests exercised real pairing, app-keyring persistence and BLE-session reuse. A later joint network-enabled attempt and one agreed manual Retry failed at Wi-Fi; successful association and camera HTTP verification remain unestablished. The previous generic error hid the cause. Levelled sanitized diagnostics and fail-fast error handling are now implemented and offline-tested; another real run requires joint approval. Real Pair is disabled unless both development approval flags are set. The owner subsequently authorized a joint pairing-enabled run; the actual app now reports BLE-session success. The owner confirmed selecting Pair and approving on the camera; the first attempt failed, then manual Retry reached BLE-session success. The initial error, Retry path and keyring prompts remain unverified. A later owner-approved restart read the saved keyring record but failed at remembered-camera lookup, before any session/new-pairing write. After the lookup correction, another owner-approved fresh app launch reused saved pairing and reached BLE-session success without Pair or Retry; the owner confirmed the result. This verifies process-restart BLE reuse for that run, not full Wi-Fi/HTTP reconnect; see the [evidence](development/evidence/issue-2/README.md#joint-ble-session-result--2026-11-17). App/adapter tests cover explicit approval, refusal, remembered reuse and keyring failures. The full network path and affected failure cases still need actual-camera validation. The owner subsequently approved system keyring unlock prompts and continuing after successful storage access; see [ADR 0005](decisions/0005-keyring-unlock-prompts.md). Real unlock/cancel/failure behavior remains unverified.


- Launch directly into Gallery, without a separate home screen. Show connection progress/status, photo filenames, an empty state, or a clear failure message. Put the Gallery title and connection status at the top, with the filename list below. Loading, empty and error states use that same content area; errors offer Retry. No sidebar or extra navigation is included in this slice. Initial desktop window size is **1000 × 700 logical pixels**, with layout validation down to **640 × 480 logical pixels**. These are agreed design/check sizes, not measured rendering results or an enforced minimum window size. Use standard Material 3 controls without a custom theme or design system for this slice. A later presentation-only theme can use Flutter `ThemeData` without changing camera or application logic.
- Basic accessibility for this slice: camera selection, **Pair** and **Retry** must be keyboard-operable, keyboard focus must be visible, and connection status must use text rather than color alone. Camera selection passed keyboard integration testing in the running Linux app with simulated data. Keyboard Pair and Retry also passed running-app integration tests with simulated boundaries; native dialog and remaining accessibility checks are pending.
- First-time setup shows discovered YI M1 cameras in the same Gallery content area. Select a camera, even if only one is found, then press **Pair** to authorize initiating pairing; selection alone must not start pairing. Required camera-screen approval still applies. Reconnect automatically to the remembered camera on later visits.
- Join camera Wi-Fi automatically without an extra application confirmation. This may interrupt internet access; camera-side approval and required OS authorization still apply. Keep the app-created camera Wi-Fi profile only in memory and remove it when that network connection ends; do not save it to disk or modify existing user profiles. Supply Wi-Fi credentials to NetworkManager only for connection use; do not let NetworkManager or its desktop agents persist a separate copy. This does not add manual Disconnect or previous-network restoration.
- List all JPEG and RAW files, fetching additional pages when needed. Use one filename row per file, with no RAW+JPEG grouping.
- Sort usable camera-provided timestamps newest first; put files without usable timestamps last, sorted by filename. Research identifies a `date` field, but its capture-time meaning needs hardware validation.
- Allow up to **two minutes (120 seconds) per connection attempt**, then identify the failed step and offer manual Retry. No automatic retry loop. The limit is an agreed product choice, not a measured protocol requirement.
- Retry remembered connections without silently starting new pairing. Failure alone does not prove invalid pairing; there is no evidence of time-based expiry. Re-pairing requires explicit approval.
- Store pairing secrets in the desktop keyring through an application-owned, platform-neutral storage port. If the keyring is locked, allow the system unlock prompt and continue only after unlock and the required storage operation succeed. On cancellation, denial, unlock failure or unavailable/failed storage, stop the connection attempt, explain the storage problem and offer manual Retry; do not fall back to plain-text storage or initiate new pairing. Android/iOS adapters may differ; they are not implemented in this slice. The owner approved **`flutter_secure_storage` 11.2.0** (BSD-3-Clause) inside the desktop storage adapter; its Linux implementation uses `libsecret`. Remember the camera identity and pairing key/token; read fresh Wi-Fi credentials from the camera on each connection instead of persisting its Wi-Fi password. Exact identity representation and serialization must follow validated protocol needs. The Linux plugin builds, and saved-record reuse across process restart passed. Locked/unavailable keyring behavior remains unverified.

Thumbnails, previews, downloads, Live, manual Disconnect, automatic link-loss recovery, and restoring the previous Wi-Fi network are outside this slice, not removed from broader product scope. Automated discovery/UI checks use simulated boundaries. Joint real tests cover BLE-session reuse, not complete connection acceptance.

## Not currently in scope

- A web release: earlier research considered it, but the current target list is Linux, Android and iOS. Do not add a web target without discussion.
- Video recording/download, advanced exposure/focus controls, camera-file deletion, firmware updates, cloud accounts or cloud sync. A live video feed is not a request to record video.
- Automatic download after a remote shot.

These are current boundaries, not permanent prohibitions if later approved as new stories. Do not add them as hidden side effects of gallery/live work.

## Protocol constraints supported by research

- BLE handles pairing/session setup and enabling camera Wi-Fi; Wi-Fi carries stored-photo access and live view.
- Source evidence identifies local HTTP photo access and a separate UDP live-view path. See [protocol prior art](research/protocol-prior-art.md) and [original app analysis](research/original-app-analysis.md).
- A new pairing may replace an old one. Camera-screen approval and user authorization matter.
- Existing clients report firmware 3.2-int tests, but this project has not reproduced them.
- Local operation without vendor cloud login is supported by source evidence; end-to-end reliability remains to be validated.

These facts guide feasibility; they are not a complete implemented protocol contract. Do not substitute YI Home/action-camera APIs.

## Technical choices and remaining validation

Approved selections below are not questions to reopen; their operational validation is still pending. Later-slice questions remain unresolved. Resolve only those needed by the next story; during Q&A ask one question at a time. Record each resolved point in its issue and affected maintained documents as soon as it is agreed.

- Selected integrations are recorded below and in the environment record; remaining integration details still need validation. The owner approved pinning **Flutter 3.44.4 stable with its bundled Dart 3.12.2** for issue #1 on 2026-11-17, retaining the installed SDK without upgrading. [Environment inspection](development/environment.md) found the Linux toolchain ready; the Linux app build/integration tests pass with simulated boundaries; full camera connection validation remains pending.
- BDD automation is agreed: standard Flutter `flutter_test` and SDK `integration_test`, with Given/When/Then scenarios mapped to named Dart tests; no separate Gherkin runner or feature generator. See the [testing guide](development/testing.md#use-standard-flutter-tooling-for-bdd). Native keyring and OS authorization dialogs will be checked manually on the target PC alongside automated app tests; no desktop automation framework is selected for this slice. Those checks are pending. Linux screenshots will use the installed ImageMagick `import` tool to capture only the app window, with visual inspection before publication; selection screenshots have now been captured and inspected in the running Linux app with simulated discovery. Sanitized screenshot evidence will be stored in the repository and embedded in the PR, without a separate hosting service. Verified commands are in the [connection guide](development/connection.md). Discover remaining tools incrementally and standardize after practical validation.
- Linux BLE library approved on 2026-11-17: **`bluez` 0.9.0** (MPL-2.0), confined to the Linux adapter. Dependencies resolve; complete camera compatibility remains unverified; future mobile adapters may use different libraries. The owner superseded the earlier `nm` 0.6.0 choice on 2026-11-17: use a **narrow project-owned Linux NetworkManager adapter over `dbus`**, reusing the transport already required by `bluez`, without the `nm` wrapper. Declare `dbus` directly when importing it and resolve a version compatible with `bluez`; no new exact version pin is implied. Limit custom code to the calls, state events and error translation needed by this slice; do not implement D-Bus or Wi-Fi management itself. Dependencies now resolve in `pubspec.lock`: `bluez` 0.9.0, `dbus` 0.8.0, `flutter_secure_storage` 11.2.0 and Linux implementation 3.0.3. Package resolution does not validate runtime integration. Operational permission checks and the exact secret-supply mechanism remain unverified; the approved policy supplies Wi-Fi credentials only for connection use, without a separately persisted NetworkManager/desktop-agent copy; the camera Wi-Fi profile must be memory-only and removed when its connection ends; see the [environment record](development/environment.md).
- Preview behavior for RAW-only files and later RAW+JPEG selection/grouping. First-slice complete filename listing is agreed; wire pagination and timestamp semantics still need validation.
- Download destination, naming/conflicts, cancellation and partial-file handling.
- Live-view/shutter interaction, errors, link-loss recovery and camera-mode constraints.
- Persisted pairing policy is agreed: camera identity and pairing key/token, with fresh Wi-Fi credentials read on each connection and no persisted camera Wi-Fi password. The versioned keyring record stores address/address type, protocol, reference and token. Its reuse across process restart passed; broader identity-change and failure behavior remains unverified. The desktop-keyring library is approved: `flutter_secure_storage` 11.2.0; its Linux build requires `libsecret-1-dev`, now installed and verified under separate approval. Locked-keyring behavior is agreed in [ADR 0005](decisions/0005-keyring-unlock-prompts.md): allow the system unlock prompt and continue on successful storage access; cancellation, denial or failure stops with a clear storage error and manual Retry, with no plain-text fallback or new pairing.
- The owner approved disconnecting the temporary camera Wi-Fi connection when the app closes or crashes; see [ADR 0004](decisions/0004-camera-network-lifetime.md). Real close/crash cleanup remains unverified.
- The owner deferred competing-route/interface protection to [issue #4](https://github.com/cltec/yi-m1-reborn/issues/4); it does not block #1/#2/#3. Source-IP binding alone does not guarantee camera Wi-Fi egress under overlapping Ethernet/VPN routes. Record this limitation in validation/review evidence; no conflicting-route support or authenticated-camera guarantee is claimed. The network-enabled app reached its Wi-Fi failure path in the joint attempt; old logs do not identify the exact failed NetworkManager call or cause. See [validation limits](development/connection-blockers.md). Hardware/network runs still require separate joint approval. No new routing CLI/dependency/native layer or storage plugin was selected.
- Project license and distribution/signing process. No license has been selected; public repository access is not a reuse license.

Do not interpret these as a questionnaire to ask in bulk.

## Glossary

| Term | Meaning |
| --- | --- |
| Camera | The owner's YI M1 running 3.2-int unless a test explicitly names a different device. |
| Gallery | Stored images on the camera, not a phone/desktop photo library. |
| Preview | An image rendition for viewing; not necessarily the full original or native RAW decoding. |
| Original | The unmodified source file downloaded from the camera. Validate integrity against the card when testing. |
| Live view | The camera's current video feed, separate from stored-media downloads and video recording. |
| Remote shot | A photo triggered by the app and saved on the camera. |
| Pairing | User-authorized camera/client registration, distinct from Wi-Fi association and session reuse. |
| Vertical slice | A small observable capability spanning the required UI, use case, adapters and tests. |
| Port | An application-owned boundary for an action or external capability, not a wrapper for every utility. |
| Adapter | Code translating UI/platform/protocol details at a port boundary. |

## Agreements and provenance

The owner approved one issue-linked feature branch/PR per vertical slice, documentation in `docs/` with code, and real target-desktop/camera validation before completing hardware-dependent work. UI expectations are agreed before implementation. Every UI-touching feature requires launching and exercising the target application, capturing and inspecting screenshots, and embedding evidence in the PR. Safe, current screenshots may also illustrate maintained documentation; documented steps must be checked against the running application.

The first approved feature will be used to discover suitable tools incrementally and standardize them after practical validation. Approved tools and unresolved details are recorded above and in issue #1; selection does not establish operational compatibility. The agent prepares the branch, runs checks, updates docs and opens the PR; the owner reviews, approves and merges. Cosmetic changes and other changes without camera-communication impact may merge after applicable checks pass, without new camera validation. Protocol or camera-communication changes require successful actual target desktop (Pop!_OS 22.04 for issue #1) + M1 3.2-int validation before merge; assess behavioral impact, not only which layer contains the edit. Full process and completion criteria are in [workflow](development/workflow.md) and [testing](development/testing.md).

The initial repository/documentation scaffold was expressly authorized **without an issue**. It does not itself authorize application development, issue creation, a GitHub push or a license choice. The later Flutter/Dart selection and issue #1 updates were separately authorized.

The [research](research/README.md) predates these scope confirmations. Preserve its uncertainty as historical evidence; use this page for current scope. Architectural rationale lives in [ADRs](decisions/README.md), not in chat-only memory.
