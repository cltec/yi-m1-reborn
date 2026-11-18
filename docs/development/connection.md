# Develop and validate the camera connection

Use this guide for [issue #2](https://github.com/cltec/yi-m1-reborn/issues/2) on Pop!_OS 22.04 with the owner's YI M1 firmware 3.2-int. Photo filename listing is a later increment, [#3](https://github.com/cltec/yi-m1-reborn/issues/3).

## Prepare and check the workspace

Use Flutter **3.44.4** with bundled Dart **3.12.2**, recorded in `.flutter-version`, and retain `pubspec.lock`. The file records the version; it does not install/switch SDKs. GTK/Clang/CMake/Ninja and `libsecret-1-dev` are required. The owner installed the missing `libstdc++-12-dev`; Linux builds now pass. Ask the owner to install anything else.

From the repository root:

```text
flutter test
flutter analyze
dart format --output=none --set-exit-if-changed lib test integration_test test_support
flutter test integration_test/gallery_test.dart -d linux
git diff --check
```

The latest full suite passes **130 automated tests**, static analysis is clean, and **4 Linux integration tests** pass. Adapter tests use isolated in-process D-Bus services and local HTTP fixtures; they do not prove host NetworkManager, keyring failure policy or camera compatibility. The integration tests exercise keyboard selection, Pair, Retry and simulated connection at the application boundary. View-size overrides are layout checks, not native GTK resizing evidence.

## Launch safely without camera operations

```text
flutter run -d linux
```

With no approval flags, the development entry point displays a discovery-approval error and Retry; it does not open camera/keyring/network adapters. Flags are build/run execution gates, not standing authorization. Keep them off during unattended work.

To exercise the actual Linux app with simulated external boundaries:

```text
flutter run -d linux -t test_support/gallery_preview.dart
flutter run -d linux -t test_support/connection_preview.dart
flutter run -d linux -t test_support/connection_preview.dart --dart-define=PREVIEW_STATE=progress
flutter run -d linux -t test_support/connection_preview.dart --dart-define=PREVIEW_STATE=error
```

The second fixture shows Connected; the other modes show response progress or failure. None accesses the real camera, keyring or host NetworkManager. These fixtures were launched, resized to the agreed 1000 × 700 and 640 × 480 GTK content sizes, captured with ImageMagick `import` and visually inspected. Text fits, Connected does not imply media has loaded, and manual Retry is keyboard-operable. See [evidence](evidence/issue-2/README.md#offline-connection-ui-checks--2026-11-17). Images are local and not yet embedded in a PR.

## Resume the real-camera checks with the owner

**Do not run a new camera/network test unattended.** The owner authorized offline development while away, with further real tests deferred to the next joint session. A later joint network-enabled attempt and one manual Retry failed at Wi-Fi; see [evidence](evidence/issue-2/README.md#joint-network-enabled-attempt--2026-11-18). No successful Wi-Fi/status result is established.

Completed joint evidence:

- A filtered LE discovery returned one candidate; cached candidates alone do not establish availability.
- The owner selected Pair and approved on the camera. The first app attempt failed with an unremembered error; manual Retry reached BLE-session success. Do not claim a clean first attempt or infer its failed step.
- A fresh app launch initially failed at remembered lookup. After the correction, another approved fresh launch reused the saved app-keyring record and reached BLE-session success without Pair or Retry. The owner confirmed the display. No Wi-Fi activation/association or camera HTTP request ran. Camera-power-cycle recovery was not tested.

See [real restart evidence](evidence/issue-2/README.md#remembered-restart-retest--ble-session-succeeded-2026-11-17). Do not pair again to repair remembered lookup.

### Accepted network lifetime

The owner approved disconnecting temporary camera Wi-Fi when the app closes or crashes; see [accepted ADR 0004](../decisions/0004-camera-network-lifetime.md). The staged adapter uses `bind-activation="dbus-name"` for caller-loss cleanup. Actual close/crash disconnection and removal of the owned profile remain unverified. This approval does not authorize a network-enabled run or changes to user profiles.

### Deferred competing-route protection

Source-address binding does not select a Linux egress interface. An Ethernet/VPN/other network with an overlapping subnet could receive the request instead of the camera. NetworkManager D-Bus route metadata does not resolve the kernel's complete source/policy routing decision. The owner deferred protection to [issue #4](https://github.com/cltec/yi-m1-reborn/issues/4); it does not block #1/#2/#3 or ordinary connection validation. Record the test network setup and this limitation. No new CLI, package or native socket layer was selected. Do not treat a manual absence of obvious overlap as an implemented route guarantee.

### Agree the next narrow test

Obtain separate joint approval to reuse the saved pairing, enable camera Wi-Fi with `da5` ASCII `ON`, join its network using fresh credentials and make one read-only `GetCameraStatus` request. This can interrupt Internet access. Required OS authorization may occur; stop on unexpected prompts. No new pairing, camera mode/time/settings change, media listing or file operation is needed. Agree profile/password inspection scope without displaying credentials.

Only after scoped joint execution approval is obtained, the command is:

```text
flutter run -d linux --dart-define=CAMERA_DISCOVERY_APPROVED=true --dart-define=CAMERA_PAIRING_APPROVED=true --dart-define=CAMERA_NETWORK_APPROVED=true
```

**The joint run on 2026-11-18 and one agreed manual Retry failed at Wi-Fi.** The older app emitted only a generic error; its cause is unknown. Observability/error-handling corrections are now implemented and offline-tested; another real run needs separate joint approval. Without `CAMERA_NETWORK_APPROVED`, the two earlier flags enable only pairing/keyring/BLE-session testing, never `da5`, NetworkManager or HTTP. The three flags do not replace user authorization. New Pair remains an explicit, separately approved action because it may replace camera registration.

Expected next outcome: saved pairing → fresh BLE credentials → AP enable → temporary Wi-Fi → valid camera status → Connected. Record the failed stage if it stops; do not broaden the probe or automatically retry. Check restart/reuse, owned-profile removal and no separately saved password under agreed conditions before marking full C2/C5 acceptance. Do not lock the owner's keyring or alter profiles to manufacture failure without explicit approval.

## Implemented boundaries and assumptions

- `PairCamera` owns storage, explicit pairing, remembered resume, optional network join, response verification and connection lifetime. Network credentials are passed through, not saved. The core imports no Flutter/platform client types.
- BLE pairing preflights capabilities/protocol-1 firmware, subscribes `da7`, sends `da0` once and saves accepted identity/reference/token before resumed session setup. Pending accepted material survives a save failure in memory for storage-only Retry, not app exit.
- Resume resolves exact stored address/address type without requiring cached service UUIDs. If absent, one service-filtered LE rediscovery window (up to 10 seconds) runs on the first powered adapter. Only one exact identity is accepted; changed random identity or ambiguous matches fail. Actual M1 GATT/session capabilities are checked before session writes.
- Network-enabled resume additionally preflights `da5`, writes `da4`, reads fresh `da6`, then writes `ON` once. Advertised write-with-response is preferred, otherwise advertised write-without-response; no blind fallback. Source ordering is documented in [protocol research](../research/protocol-prior-art.md). The joint network run progressed to the Wi-Fi step after this adapter flow; no independent BLE wire capture was made. The owner saw camera Wi-Fi connection in progress.
- The narrow NetworkManager adapter uses `AddAndActivateConnection2`, `persist="volatile"`, accepted `bind-activation="dbus-name"`, no autoconnect, WPA-PSK `psk-flags=2` (`NOT_SAVED`), automatic IPv4 without default-route/DNS takeover and disabled IPv6. It selects the first available managed Wi-Fi device without changing power. It waits for activated state and a local IPv4 address, and releases only its owned activation/profile. Known link loss hides Connected immediately; manual Retry waits for owned cleanup to settle. These settings are requests, not proof of no desktop-agent password persistence.
- HTTP uses `GET http://192.168.0.10/?data=<encoded JSON>` with `GetCameraStatus`. It binds a literal local IPv4 source, disables proxy/redirect/retry and automatic decompression, and caps status data at **16 KiB** (a developer-selected bound, not a measured camera maximum). It requires HTTP 200, JSON code 200, and string integer `batteryLevel`/`SurplusPhotoCnts`. This schema is source-informed and still needs target-camera validation. It does not list files or interpret a free-photo count as an empty card. Source-address binding is not itself proof of interface/route correctness under conflicting subnets; record the network setup and deferred protection in validation evidence; competing-route protection belongs to #4.


## Connection diagnostics and unexpected errors

The production entry point writes structured JSON diagnostic lines to stderr. It does not create a persistent log file or send telemetry. Essential stage/outcome events use `info`, degraded/cleanup conditions use `warning`, failures use `error`. Development detail requires `--dart-define=CAMERA_DEBUG_LOGS=true`; it does not grant camera-operation approval. Camera approval flags remain separate.

Events carry safe stage names, elapsed milliseconds, error categories and numeric platform state/reason codes where available. Never log credentials, pairing tokens, SSIDs, addresses/device identifiers or raw platform messages/payloads. Console stack output keeps Dart SDK and project package frames only; raw platform traces and local filesystem frames are omitted. Review even sanitized output before publishing.

Adapters translate only explicitly managed transport/protocol/storage failures. Unexpected errors retain their identity and stack and propagate to error reporting, not a generic Wi-Fi error. A final error observer may log and rethrow; it must not become catch-all recovery. Failed-attempt cleanup reports secondary errors without replacing the primary error. Unexpected launch errors consumed by FutureBuilder are explicitly reported and do not offer ordinary Retry.

The two initial real network-enabled attempts failed with only a generic Wi-Fi message. Their cause cannot be reconstructed from the old output. These corrections improve the next attempt's evidence; they do not establish that Wi-Fi activation is fixed. Further camera runs require joint approval.

## Remaining acceptance limits

Issue #2 stays open. The owner approved offline #3 application/UI development through ports and simulated adapters while the camera is unavailable; real connection/listing integration remains a final hardware acceptance and merge requirement. See [connection validation blockers](connection-blockers.md) for the source review and required decisions.

- **Keyring C4 — policy resolved, validation pending:** the owner approved the system unlock prompt and continuation only after successful storage access; see [ADR 0005](../decisions/0005-keyring-unlock-prompts.md). Canceled/denied/failed unlock or unavailable/failed storage must stop with a storage error and manual Retry, never missing-pairing fallback. The selected plugin remains unchanged. Native prompt success and failure behavior still need validation.
- **Deadline C3:** pairing, storage, resumed BLE, optional network and HTTP share the existing 120-second operation budget. Initial discovery has its own bounded 120-second adapter budget. Human selection is between attempts. Cleanup can add one second per platform resource (up to two steps for discovery and about three for network activation cleanup), so a strict wall-clock 120-second result is not yet established. Platform work already sent cannot be undone by a Dart timeout; late side effects require attention during failure validation.
- **Privacy C5:** process-restart keyring reuse passed, but actual NetworkManager/agent password persistence and profile-removal checks remain pending; failed activation is not a privacy pass. Secret flags and fake settings assertions do not satisfy C5.
- **Hardware C7:** full first connection, complete remembered connection, network failures/storage failures and safe HTTP response remain pending. Earlier BLE success does not satisfy them. No settings, files or firmware were changed by overnight work.

No new dependencies, SDK versions, framework, license, installation, push or PR was introduced during this continuation. The branch remains an uncommitted implementation for review and joint validation, not a completed connection slice.
