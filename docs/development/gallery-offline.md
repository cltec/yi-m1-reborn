# Develop Gallery without the camera

Remaining implementation and validation are tracked in [linked follow-up issues](remaining-work.md); the owner requested a combined development branch and draft PR, not completion or merge.

Use this guide for the owner-approved offline work in [issue #3](https://github.com/cltec/yi-m1-reborn/issues/3). The camera is unavailable. These runs use synthetic metadata, not camera files or verified wire responses.

## Run the simulated app

Use the existing pinned Flutter 3.44.4 / Dart 3.12.2 environment from the repository root:

```text
flutter run -d linux -t lib/main_simulated.dart
flutter run -d linux -t lib/main_simulated.dart --dart-define=SIMULATED_CATALOG=empty
flutter run -d linux -t lib/main_simulated.dart --dart-define=SIMULATED_CATALOG=error
flutter run -d linux -t lib/main_simulated.dart --dart-define=SIMULATED_CATALOG=loading
```

The title area says **Simulated camera — no camera access**. The default synthetic catalog includes separate JPEG/RAW rows and same-named photos with distinct identities. The error scenario fails the first listing; manual Retry loads the catalog on the same connection. Loading waits until cancellation. `SIMULATED_CATALOG=unexpected` exercises unexpected-error reporting rather than an ordinary Retry.

The simulated entry point constructs only simulated connection/catalog capabilities. It does not touch BlueZ, NetworkManager, the keyring, HTTP or camera files. `lib/main.dart` remains the guarded real entry point; no approval flags are required or implied by offline runs. `CAMERA_DEBUG_LOGS=true` enables development-level diagnostics; default info/warning/error remains available. Logs never include filenames, media identities, credentials or addresses.

## Verify application behavior

```text
flutter test
flutter analyze
flutter test integration_test/gallery_test.dart -d linux
dart format --output=none --set-exit-if-changed lib test integration_test test_support
git diff --check
```

Exercise loading, populated, empty and error/Retry in the actual Linux app at 1000 × 700 and 640 × 480. Check keyboard Retry and readable status. Capture app-window-only screenshots with the already approved ImageMagick `import` workflow; inspect before publication. Identify all fixture images as simulated. Integration view-size overrides are not native-window screenshot evidence.

## Boundaries and pending integration

Gallery depends on `CameraConnection` and `LoadGallery`, not concrete device libraries. Existing `PairCamera` implements the connection contract and retains pairing/storage/BLE/network/reachability behavior. A verified active `CameraNetworkSession` is handed to `CameraPhotos`, so listing never creates a second Wi-Fi connection or relies on a BLE-only success result. `LoadGallery` owns ordering, request lifetime and managed/ unexpected outcomes. Concrete adapters own transport, paging and wire decoding.

The metadata contract returns a complete catalog or failure. Ordering uses supplied usable timestamps newest first; undated names follow, with identity breaking ties. A timestamp is not claimed to be capture time. Duplicate filenames remain separate files; duplicate identities are invalid, not silently collapsed.

The real `GetFileList` adapter is not implemented/validated by this offline work. Wire response shape, JPEG/RAW representation, pagination/end conditions and timestamp meaning remain final integration work alongside #2's unresolved real Wi-Fi failure. No synthetic result satisfies hardware acceptance or permits merging unvalidated camera-communication changes. #4 competing-route protection stays deferred.

## Branch relationship

The #2 baseline was preserved locally in commit `4b43b2c` on `feat/2-camera-connection`, without push or PR. #3 uses `feat/3-gallery-filenames` stacked on that baseline. Review its diff against #2, not directly against main while #2 is unmerged. The local WIP commit is not a completed or hardware-validated connection release.

## Latest offline checks — 2026-11-18

- `flutter test`: **165 passed** (includes 14 listing-use-case tests and 13 simulated-adapter tests).
- `flutter analyze`: **no issues**.
- `flutter test integration_test/gallery_test.dart -d linux`: **5 passed**. Added simulated listing failure → keyboard Retry → separate JPEG/RAW rows at both agreed view sizes; existing connection journeys still pass.
- All operation lifetime/sorting/identity/managed-error/ unexpected-error claims above are application/simulation results only. The first concurrent full run caught an in-progress loss regression red; the final settled suite passed. No hardware outcome changed.

See [offline UI evidence](evidence/issue-3/README.md) for inspected populated/error native-window captures and evidence limits. Loading capture was obscured by a desktop/lock overlay and discarded; loading/empty native screenshots remain pending an accessible desktop. No unlock/security-policy change was attempted. SDK Linux keyboard Retry passed; separate native xdotool activation was inconclusive. No new dependency, SDK version, platform, timeout or camera-wire constant was selected. Synthetic fixture filenames, identities and UTC dates are test data, not camera contracts. Listing cancellation relies on each adapter honoring cancellation and settling owned requests before returning; the real adapter must implement and validate that contract.
