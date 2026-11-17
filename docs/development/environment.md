# First desktop environment

Read-only inspection on **2026-11-17** for [issue #1](https://github.com/cltec/yi-m1-reborn/issues/1). These are installed capabilities, not proof that the app works. The owner subsequently approved pinning **Flutter 3.44.4 stable with its bundled Dart 3.12.2** for issue #1 on the same date; the Linux BLE library `bluez` 0.9.0 was also approved. The initially approved Wi-Fi wrapper `nm` 0.6.0 was subsequently superseded by a narrow project-owned NetworkManager adapter over `dbus`. The owner subsequently approved `flutter_secure_storage` 11.2.0 for the desktop-keyring adapter. No application has been built or launched, and no camera connection has been attempted.

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

## Approved Linux BLE library

On 2026-11-17 the owner approved **`bluez` 0.9.0** for the Linux BLE adapter. It is a direct Dart client for the installed BlueZ service, avoiding an extra cross-platform wrapper for this first slice. Keep its types and D-Bus details outside domain/application code. Future Android/iOS adapters may use different libraries.

Published package metadata declares Dart `>=3.0.0 <4.0.0`, which includes the pinned Dart 3.12.2, and MPL-2.0 licensing. This is source/metadata inspection, not successful dependency resolution, build or camera validation. Distribution must account for dependency license obligations; the project license remains undecided. No dependency was installed by this approval.

Sources inspected on 2026-11-17: [package metadata](https://pub.dev/api/packages/bluez), [versioned package](https://pub.dev/packages/bluez/versions/0.9.0), and its [published archive](https://pub.dev/api/archives/bluez-0.9.0.tar.gz) containing the manifest, license and client APIs.

## Approved Linux Wi-Fi integration

On 2026-11-17 the owner initially approved `nm` 0.6.0, then **superseded that choice** with a narrow project-owned NetworkManager adapter using the Dart **`dbus`** transport already required by `bluez`. Do not add the `nm` wrapper. Dart/Flutter do not include a high-level NetworkManager client. The project owns only the NetworkManager calls, connection-state observation and error translation needed by this slice; NetworkManager still performs Wi-Fi management. Keep D-Bus types outside the application/domain. Future mobile adapters may use different integrations.

Declare `dbus` as a direct dependency when importing it, even though `bluez` already requires it transitively. Resolve a version compatible with the selected `bluez` package; no additional exact version pin was approved. This removes a wrapper, not the D-Bus transport, and trades wrapper maintenance for narrowly scoped project-owned API calls. Dependency resolution, build, Wi-Fi association and camera routing remain untested.

On 2026-11-17 the owner approved keeping the app-created camera Wi-Fi profile **only in memory**, removing it when that network connection ends rather than saving it to disk. Do not edit or delete existing user profiles. This does not define app-exit disconnection, add a manual Disconnect control, or restore the previous Wi-Fi network.

Use NetworkManager 1.36.6 `AddAndActivateConnection2` with `persist="volatile"` through the project-owned D-Bus adapter to meet the approved memory-only profile lifetime and removal on disconnect. Do not use the ordinary disk-persistent activation default. Exact adapter code must be derived incrementally and tested; no activation has been attempted. This does not add app-exit disconnection or previous-network restoration.

The owner also approved supplying Wi-Fi credentials to NetworkManager **only for connection use**, without allowing NetworkManager or its desktop agents to persist a separate copy. Remembered secrets remain under the agreed application-owned keyring storage policy; the selected library is `flutter_secure_storage` 11.2.0. Remember camera identity and pairing key/token; obtain fresh Wi-Fi credentials on each connection instead of persisting the camera Wi-Fi password.

Verify that no camera profile is written to disk, that the app-created profile is removed when the connection ends, and that no separate credential copy is persisted by NetworkManager or a desktop agent. Profile persistence alone does not establish credential persistence behavior. Where applicable, NetworkManager's `NOT_SAVED` secret flag (`2`) is an implementation candidate, not a validated mechanism; it does not register the application's keyring adapter as a NetworkManager SecretAgent. Exact credential-supply behavior and agent interactions still need implementation and target-desktop testing. Never log credentials or D-Bus maps containing them.

Secret-flag reference: [NetworkManager secret flags](https://networkmanager.dev/docs/api/latest/secrets-flags.html), inspected on 2026-11-17. This policy does not claim that transient secrets are absent from process memory, swap or crash dumps.

Sources inspected on 2026-11-17: [Dart D-Bus package](https://pub.dev/packages/dbus), [BlueZ manifest](https://pub.dev/api/archives/bluez-0.9.0.tar.gz), and the superseded-wrapper evidence: [package metadata](https://pub.dev/api/packages/nm), [versioned package](https://pub.dev/packages/nm/versions/0.6.0), [published archive](https://pub.dev/api/archives/nm-0.6.0.tar.gz), and [NetworkManager 1.36.6 API XML](https://raw.githubusercontent.com/NetworkManager/NetworkManager/1.36.6/introspection/org.freedesktop.NetworkManager.xml). Package source and license inspection is not runtime validation or selection of the project license.

## Approved desktop-keyring library

On 2026-11-17 the owner approved **`flutter_secure_storage` 11.2.0** (BSD-3-Clause) inside the desktop storage adapter, behind the application-owned, platform-neutral port. Its default Linux implementation uses `libsecret` and a desktop keyring service. Keep Flutter/plugin types outside the application/domain. Future mobile adapters may use different implementations; this selection does not establish mobile support.

Published constraints are Dart `>=3.8.0 <4.0.0` and Flutter `>=3.19.0`, which include the pinned SDK versions. Dependency resolution and build have not been run. The Linux implementation requires `libsecret-1-dev` for building and `libsecret-1-0` at runtime. The runtime package is installed on this PC; the development package is absent. No package was installed by this approval.

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
