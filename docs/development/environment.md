# First desktop environment

Read-only inspection on **2026-11-17** for [issue #1](https://github.com/cltec/yi-m1-reborn/issues/1). These are installed capabilities, not proof that the app works. The owner subsequently approved pinning **Flutter 3.44.4 stable with its bundled Dart 3.12.2** for issue #1 on the same date; the Linux BLE library `bluez` 0.9.0 was also approved. The initially approved Wi-Fi wrapper `nm` 0.6.0 was subsequently superseded by a narrow project-owned NetworkManager adapter over `dbus`. The owner subsequently approved `flutter_secure_storage` 11.2.0 for the desktop-keyring adapter. The initial inspection predates implementation; see the latest-state summary below and dated evidence for later app launches and BLE-session validation.

The initial inspection tables below retain their original observations. The later installation verification records the current `libsecret-1-dev` status.

## Offline Gallery development approval — 2026-11-18

Camera unavailable. The owner approved starting #3 application/UI development now through application-owned Ports and Adapters and a simulated camera adapter, with real integration last. #1/#3 specifications updated. Existing pairing/storage/network/reachability ports already isolate external systems; add only the connection/session and filename-list capabilities actually needed by Gallery. Do not introduce a speculative all-purpose camera API or expose platform types to the core. Use the same application workflow for simulated and real adapters, selected at composition roots; visibly label the simulated app.

#2 stays open with real Wi-Fi failure undiagnosed. Current baseline: 130 automated tests, four simulated Linux integration tests, clean analysis/format/whitespace. No new camera or system operation is authorized. Real listing wire format, paging/end conditions and timestamp meaning remain unverified; final hardware acceptance/communication merge gates remain. No new dependency/platform/feature scope is selected.

The #2 implementation and earlier documentation edits are preserved in local WIP commit `4b43b2c` on `feat/2-camera-connection`; #3 development is on stacked branch `feat/3-gallery-filenames`. Nothing pushed, merged or hardware-validated by that checkpoint. Offline tracer bullet: simulated verified session → application filename-list capability → Gallery rows, then incremental sorting/loading/empty/error/Retry/loss behavior with levelled diagnostics and fatal unexpected-error reporting.

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

## Measured tools and services

| Area | Observation | Check |
| --- | --- | --- |
| OS | Pop!_OS 22.04 LTS, Ubuntu `jammy` base, x86-64 | `/etc/os-release`; `flutter doctor -v` |
| Flutter | Stable 3.44.4, revision `ad70ec4617166f1c38e5d2bfd388af71fda14f06` | `flutter --version --machine` |
| Dart | 3.12.2, bundled with that Flutter SDK | `flutter --version --machine` |
| Linux desktop toolchain | Doctor reports Linux toolchain ready and Linux desktop enabled | `flutter doctor -v` |
| Build tools | clang 14.0.0, CMake 3.22.1, Ninja 1.10.1, pkg-config 0.29.2, GTK development files 3.24.33 | `clang++ --version`; `dpkg-query -W`; `pkg-config --modversion gtk+-3.0` |
| C++ development library | `libstdc++-11-dev` installed; `libstdc++-12-dev` absent | `dpkg-query -W` |
| Bluetooth | BlueZ 5.64; service active; adapter powered, reporting central and peripheral roles | `bluetoothctl --version`; `systemctl show`; D-Bus property reads |
| Network management | NetworkManager 1.36.6 active; Wi-Fi enabled and connected | `nmcli --version`; `nmcli general`; `systemctl show` |
| Network authorization | Current session reports `yes` for Wi-Fi scan, network control, and modifying own/system connections | `nmcli general permissions` |
| Bluetooth authorization | Installed D-Bus policy allows ordinary clients to address BlueZ; adapter properties and interfaces are readable | `/etc/dbus-1/system.d/bluetooth.conf`; D-Bus introspection |
| Desktop session | X11; display and session bus available | Session environment variables |
| Screenshot tool | ImageMagick `import` 6.9.11-60 available; approved for app-window-only captures | `import -version` |
| Secret storage prerequisites | Secret Service owns `org.freedesktop.secrets`; `libsecret-1-0` installed; `libsecret-1-dev` absent | D-Bus `NameHasOwner`; `dpkg-query -W` |

## Approved V1 host-check results — 2026-11-17

After the owner approved host checks only, the readiness pass reconfirmed the measured versions above. This is not completion of V1 and does not validate camera compatibility.

| Check | Observed result |
| --- | --- |
| SDK | Flutter 3.44.4 stable, revision `ad70ec4617166f1c38e5d2bfd388af71fda14f06`; bundled Dart 3.12.2; matches approved pin |
| Linux doctor | Linux desktop/toolchain checks pass; command exits 0 but reports missing Android SDK (outside this Linux slice) |
| Rendering | Doctor still reports both listed GL extensions unavailable; no app was rendered |
| Native packages | Existing clang/CMake/Ninja/pkg-config/GTK and `libstdc++-11-dev` reconfirmed; `libstdc++-12-dev` and `libsecret-1-dev` absent |
| Bluetooth | BlueZ 5.64 active/running; adapter powered, central/peripheral roles, `Discovering=false`; three property reads succeeded |
| Bluetooth policy | Installed default D-Bus policy permits addressing `org.bluez`; no discovery/GATT operation tested |
| Networking | NetworkManager 1.36.6 active/running; Wi-Fi enabled, current connectivity full; no SSID or profile enumeration |
| Network authorization | Current session reports `yes` for Wi-Fi scan, network control and own/system connection modification; operations not exercised |
| Storage | `org.freedesktop.secrets` has an owner; runtime `libsecret-1-0` installed; no secrets accessed or written |
| Desktop/capture | X11, display/session bus present; ImageMagick `import` 6.9.11-60 available; no screenshot captured |

Commands used (SDK commands ran sequentially):

```text
flutter --version --machine
flutter doctor -v
clang++ --version
pkg-config --modversion gtk+-3.0
bluetoothctl --version
nmcli --version
import -version
systemctl show bluetooth.service NetworkManager.service --property=Id,LoadState,ActiveState,SubState
nmcli general permissions
nmcli -t -f STATE,CONNECTIVITY,WIFI-HW,WIFI general
busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.secrets
busctl --system get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Powered
busctl --system get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Roles
busctl --system get-property org.bluez /org/bluez/hci0 org.bluez.Adapter1 Discovering
dpkg-query -W -f='${binary:Package}\t${db:Status-Abbrev}\t${Version}\n' clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-11-dev libstdc++-12-dev libsecret-1-0 libsecret-1-dev bluez network-manager
```

Also read `/etc/os-release`, `/etc/dbus-1/system.d/bluetooth.conf`, and session-variable presence/type without publishing addresses or identifiers. The package query exited 1 because the two named development packages were absent; the other commands exited 0. Linux doctor passing does not establish that the selected keyring plugin can build: **`libsecret-1-dev` is still a build blocker** for that plugin. The absent `libstdc++-12-dev` did not fail the Linux doctor check and is not proposed for installation.

No installation, scan, pairing, camera command, network change, radio/settings change, personal-secret access or keyring write occurred. No production/probe code or protocol constants changed. No camera availability, pairing-state or card-inventory assumptions were promoted to verified facts.

### Remaining V1 work

- After the host checks, the owner reconfirmed on 2026-11-17 that the camera is beside this PC and powered on. The owner also confirmed the card photos are backed up; the backup was not independently checked. The owner does not know whether both JPEG and RAW photos are present; inventory/file-type coverage remains pending. Existing pairing remains uncertain. Do not delete media or change settings.
- The approved `libsecret-1-dev` installation is now verified; see the installation record below. Plugin build and keyring probes remain pending.
- Propose and obtain separate approval for minimal BLE discovery/GATT and keyring probes, including dependencies, exact commands and safe error-path checks. Do not use or lock unrelated personal keyring records. No probe code or execution is authorized by host-check approval.
- Keep V1 and all dependent tasks pending until their required evidence is obtained. Secret Service presence is not proof of an unlocked/working keyring, and readable BlueZ properties are not proof of camera access.

### Approved prerequisite installation — blocked by sudo

On 2026-11-17 the owner approved installing `libsecret-1-dev` after reviewing dependency changes. `apt-get --simulate install libsecret-1-dev` exited 0 and proposed only three new packages: `libsecret-1-dev` 0.20.5-2, `libgcrypt20-dev` 1.9.4-3ubuntu3.3 and `libgpg-error-dev` 1.43-3. No upgrades or removals were planned.

The approved attempt, `sudo -n apt-get --no-remove install -y libsecret-1-dev`, exited 1 with `sudo: a password is required`. The package transaction did not start. A subsequent `dpkg-query -W` confirmed all three packages remain absent. The owner must run `sudo apt-get --no-remove install libsecret-1-dev` in their terminal and review the transaction; do not share the sudo password in chat. Verify installation afterward. No password was requested through the agent or supplied. No probe, keyring or camera operation is authorized by this installation approval.

### Prerequisite installation verified — 2026-11-17

The first agent attempt was blocked by sudo authentication before the package transaction. The owner then reported completing the approved installation in their terminal. Verification with `dpkg-query -W` exited 0 and showed all three packages installed (`ii`):

| Package | Installed version |
| --- | --- |
| `libsecret-1-dev` | 0.20.5-2 |
| `libgcrypt20-dev` | 1.9.4-3ubuntu3.3 |
| `libgpg-error-dev` | 1.43-3 |

`pkg-config --modversion libsecret-1` exited 0 and returned `0.20.5`. The missing development-package blocker is resolved; this does not establish plugin build or keyring functionality. The full owner-terminal transaction was not observed. No secret access, probe code/execution or camera operation occurred during verification. Other installations still require approval.

## Approved Linux BLE library

On 2026-11-17 the owner approved **`bluez` 0.9.0** for the Linux BLE adapter. It is a direct Dart client for the installed BlueZ service, avoiding an extra cross-platform wrapper for this first slice. Keep its types and D-Bus details outside domain/application code. Future Android/iOS adapters may use different libraries.

Published package metadata declares Dart `>=3.0.0 <4.0.0`, which includes the pinned Dart 3.12.2, and MPL-2.0 licensing. This is source/metadata inspection, not successful dependency resolution, build or camera validation. Distribution must account for dependency license obligations; the project license remains undecided. No dependency was installed by this approval.

Sources inspected on 2026-11-17: [package metadata](https://pub.dev/api/packages/bluez), [versioned package](https://pub.dev/packages/bluez/versions/0.9.0), and its [published archive](https://pub.dev/api/archives/bluez-0.9.0.tar.gz) containing the manifest, license and client APIs.

## Approved Linux Wi-Fi integration

On 2026-11-17 the owner initially approved `nm` 0.6.0, then **superseded that choice** with a narrow project-owned NetworkManager adapter using the Dart **`dbus`** transport already required by `bluez`. Do not add the `nm` wrapper. Dart/Flutter do not include a high-level NetworkManager client. The project owns only the NetworkManager calls, connection-state observation and error translation needed by this slice; NetworkManager still performs Wi-Fi management. Keep D-Bus types outside the application/domain. Future mobile adapters may use different integrations.

Declare `dbus` as a direct dependency when importing it, even though `bluez` already requires it transitively. Resolve a version compatible with the selected `bluez` package; no additional exact version pin was approved. This removes a wrapper, not the D-Bus transport, and trades wrapper maintenance for narrowly scoped project-owned API calls. Dependency resolution, build, Wi-Fi association and camera routing remain untested.

On 2026-11-17 the owner approved keeping the app-created camera Wi-Fi profile **only in memory**, removing it when that network connection ends rather than saving it to disk. Do not edit or delete existing user profiles. This initial decision did not define app-exit disconnection, add a manual Disconnect control, or restore the previous Wi-Fi network. The later owner-approved [ADR 0004](../decisions/0004-camera-network-lifetime.md) adds disconnection on app close or crash.

Use NetworkManager 1.36.6 `AddAndActivateConnection2` with `persist="volatile"` through the project-owned D-Bus adapter to meet the approved memory-only profile lifetime and removal on disconnect. Do not use the ordinary disk-persistent activation default. Exact adapter code must be derived incrementally and tested; no activation has been attempted. App-exit/crash disconnection was subsequently approved in ADR 0004; previous-network restoration remains out of scope.

The owner also approved supplying Wi-Fi credentials to NetworkManager **only for connection use**, without allowing NetworkManager or its desktop agents to persist a separate copy. Remembered secrets remain under the agreed application-owned keyring storage policy; the selected library is `flutter_secure_storage` 11.2.0. Remember camera identity and pairing key/token; obtain fresh Wi-Fi credentials on each connection instead of persisting the camera Wi-Fi password.

Verify that no camera profile is written to disk, that the app-created profile is removed when the connection ends, and that no separate credential copy is persisted by NetworkManager or a desktop agent. Profile persistence alone does not establish credential persistence behavior. Where applicable, NetworkManager's `NOT_SAVED` secret flag (`2`) is an implementation candidate, not a validated mechanism; it does not register the application's keyring adapter as a NetworkManager SecretAgent. Exact credential-supply behavior and agent interactions still need implementation and target-desktop testing. Never log credentials or D-Bus maps containing them.

Secret-flag reference: [NetworkManager secret flags](https://networkmanager.dev/docs/api/latest/secrets-flags.html), inspected on 2026-11-17. This policy does not claim that transient secrets are absent from process memory, swap or crash dumps.

Sources inspected on 2026-11-17: [Dart D-Bus package](https://pub.dev/packages/dbus), [BlueZ manifest](https://pub.dev/api/archives/bluez-0.9.0.tar.gz), and the superseded-wrapper evidence: [package metadata](https://pub.dev/api/packages/nm), [versioned package](https://pub.dev/packages/nm/versions/0.6.0), [published archive](https://pub.dev/api/archives/nm-0.6.0.tar.gz), and [NetworkManager 1.36.6 API XML](https://raw.githubusercontent.com/NetworkManager/NetworkManager/1.36.6/introspection/org.freedesktop.NetworkManager.xml). Package source and license inspection is not runtime validation or selection of the project license.

## Approved desktop-keyring library

On 2026-11-17 the owner approved **`flutter_secure_storage` 11.2.0** (BSD-3-Clause) inside the desktop storage adapter, behind the application-owned, platform-neutral port. Its default Linux implementation uses `libsecret` and a desktop keyring service. Keep Flutter/plugin types outside the application/domain. Future mobile adapters may use different implementations; this selection does not establish mobile support.

Published constraints are Dart `>=3.8.0 <4.0.0` and Flutter `>=3.19.0`, which include the pinned SDK versions. Dependency resolution and build have not been run. The Linux implementation requires `libsecret-1-dev` for building and `libsecret-1-0` at runtime. The runtime package was already installed. The development package was initially absent, then installed under separate owner approval and verified as recorded above. Plugin dependency resolution/build and storage behavior remain untested.

The package selection does not validate the agreed stop/error/manual-Retry behavior for a locked or unavailable keyring. Check read and write failures, canceled/failed authorization, and whether the adapter can distinguish missing records from storage errors. Do not treat a failed storage read as no remembered camera or claim successful persistence after a failed write. The owner approved remembering camera identity and pairing key/token, with fresh Wi-Fi credentials read from the camera on each connection and no persisted camera Wi-Fi password. Exact identity representation and serialization remain implementation details to validate. [Protocol research](../research/protocol-prior-art.md) attributes session-varying Wi-Fi passwords to an external client report, not our own camera measurements; remembered-session reuse and fresh credential retrieval still require hardware checks.

Sources inspected on 2026-11-17: [versioned package](https://pub.dev/packages/flutter_secure_storage/versions/11.2.0), [published manifest and license](https://pub.dev/api/archives/flutter_secure_storage-11.2.0.tar.gz), and [Linux implementation documentation](https://pub.dev/packages/flutter_secure_storage_linux/versions/3.0.3). Linux 3.0.3 was inspected, not separately pinned; resolved transitive versions must be recorded when the project lockfile is created. Package licensing does not select the project's license.

## Approved Linux screenshot tool

The owner approved the installed ImageMagick `import` tool for screenshots of only the app window, with visual inspection before publication. This choice targets the measured X11 session; no Wayland support is claimed. Only `import -version` has run. No screenshot was taken, and app-window capture commands still need verification against the actual app. The owner approved storing sanitized screenshots in the repository and embedding them in the PR, without a separate hosting service. No evidence images have been captured or published yet.

## Limits and outstanding checks

- Flutter 3.44.4 stable with bundled Dart 3.12.2 is the approved SDK pin for this slice. Retain the installed SDK; do not upgrade for this slice without renewed agreement. Doctor reports a newer Flutter version available; no upgrade was performed. Reproducible application setup and build/test commands are still to be established.
- Doctor reports the Android SDK missing. It is not needed for the first Linux desktop slice.
- Doctor reports `GL_EXT_framebuffer_blit` and `GL_EXT_texture_format_BGRA8888` as unavailable. Its Linux toolchain check still passes; actual rendering and screenshot inspection remain untested.
- Library-specific native prerequisites remain subject to the selected packages. The absent development packages above do not by themselves establish that the current Linux toolchain is broken.
- BlueZ discovery, camera GATT access, and all pairing/session behavior remain untested. Readable interfaces do not prove operational permission or camera compatibility.
- Wi-Fi association, OS authorization prompts, camera routing and NetworkManager secret persistence remain untested. Current permissions can differ in another login/session.
- Secret Service ownership does not prove that a keyring is unlocked or that storing/retrieving an application secret works. No secrets were read or written. The owner approved stopping the connection attempt with a clear storage error and manual Retry if the keyring is locked or unavailable, without plain-text fallback or initiating new pairing. Both read and write failures need coverage; failed persistence must not be presented as successful remembered setup. This recovery policy is not yet implemented or tested.
- The inspection did not scan for cameras or Wi-Fi networks, pair, switch networks, install packages, or change settings. Device identifiers, SSIDs and credentials are excluded from this record.

Approved dependency choices, pending operational validation and outstanding final implementation approval are recorded in issue #1. Ubuntu 26.04, Android and iOS are not validated by this inspection.

## Issue #2 build evidence — 2026-11-17

Dependency resolution now succeeds with Flutter 3.44.4 / Dart 3.12.2: `bluez` 0.9.0, `dbus` 0.8.0, `flutter_secure_storage` 11.2.0 and Linux implementation 3.0.3. The initial guessed `dbus ^0.7.0` constraint failed because `bluez` requires `^0.8.0`; correcting it resolved the approved transport without adding a library choice. The lockfile records all transitive versions. Other-platform packages are plugin transitives, not added application targets.

`flutter test` passes 11 widget/isolated D-Bus adapter tests; `flutter analyze` passes. No real camera or host BlueZ access occurs in those tests.

The first `flutter test integration_test/gallery_test.dart -d linux` failed before launch: Clang 14 selected installed GCC 12, but only `libstdc++-11-dev` was present. A C++ compilation confirmed missing standard headers/link library. `apt-get --simulate install libstdc++-12-dev` proposed only that package, with no upgrades/removals. The owner requested doing installations personally and reported completing the proposed install. `dpkg-query -W` now verifies `libstdc++-12-dev:amd64` **12.3.0-1ubuntu1~22.04.3** installed (`ii`), and `clang++ -print-file-name=libstdc++.so` resolves to the GCC 12 library. Both checks exited 0. No agent installation command ran.

The retry passed compilation but failed installation into `/usr/local`, caused by the first failed configure caching that default before the generated Flutter bundle prefix was set. Only ignored `build/linux/x64/debug` was removed; a clean configure/build was started, without sudo or source changes to the CMake install prefix. No camera scans, GATT, pairing, keyring writes or Wi-Fi changes occurred. The clean-build retry succeeded and launched the actual Linux app. The `integration_test` keyboard camera-selection journey passed at both Flutter layout overrides (1000 × 700 and 640 × 480, scale 1) with simulated discovery. These overrides do not establish GTK window resizing or screenshots. A later native fixture run was resized, captured and inspected separately; see [visual evidence](evidence/issue-2/README.md). Both running-app integration tests now pass: keyboard selection at both layouts and keyboard Retry recovery. No camera or secret service access occurred.

## Joint real-host discovery — 2026-11-17

With the owner present and the camera reported powered on, one separately approved `flutter run -d linux --dart-define=CAMERA_DISCOVERY_APPROVED=true` run finished its service-filtered LE collection and displayed one `YI M1 1` candidate. The app-window screenshot was captured and visually inspected; see [evidence and limitations](evidence/issue-2/README.md#joint-filtered-discovery--2026-11-17). The app was stopped afterward. Real discovery calls completed without an error shown in the UI, but cached BlueZ candidates may be included; no fresh-advertisement, camera identity, firmware or GATT claim is made. No pairing, characteristic access, keyring or Wi-Fi operation ran. The preceding host-only evidence remains historical.

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
