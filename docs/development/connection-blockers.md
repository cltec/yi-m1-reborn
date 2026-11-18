# Connection validation blockers

Current limits for [issue #2](https://github.com/cltec/yi-m1-reborn/issues/2). These are not changes to approved acceptance criteria.

## Route to the camera — deferred to issue #4

The HTTP adapter binds its source to the IPv4 address returned by the app-owned NetworkManager activation. Linux source binding does **not** bind egress to that Wi-Fi interface. A competing Ethernet, VPN or Wi-Fi route to the same subnet can win. A valid-looking status reply from another host would not prove camera reachability.

The inspected [NetworkManager 1.36 Manager API](https://networkmanager.dev/docs/api/1.36.0/gdbus-org.freedesktop.NetworkManager.html) has no kernel destination/source route-resolution method. Device `GetAppliedConnection` reports settings; IP4Config `RouteData` reports that configuration's routes, not the complete kernel policy-routing decision. Checking only NetworkManager prefixes or inserting an ordinary host route is not an authoritative guarantee in the presence of policy rules.

The owner deferred this potential competing-route scenario to [issue #4](https://github.com/cltec/yi-m1-reborn/issues/4). It is **not a blocker for #1/#2/#3**. Continue ordinary connection validation under separately approved joint scope, recording the network setup and this known limitation. Source binding is not interface binding; a successful ordinary-network run does not prove competing-route protection or camera authentication. No conflicting-route support is claimed. No new CLI, dependency or native socket layer was selected or implemented.

## Network lifetime — decision resolved; validation pending

The owner approved disconnecting the temporary camera Wi-Fi connection when the app closes or crashes. [Accepted ADR 0004](../decisions/0004-camera-network-lifetime.md) amends ADR 0003. The staged adapter uses `bind-activation="dbus-name"` for daemon-owned caller-loss cleanup, including activation whose reply never arrives. The joint network-enabled attempt and one manual Retry failed at Wi-Fi without a successful activation result. Close/crash disconnection and owned-profile removal remain validation work, not observed passes.

## Locked keyring — policy resolved; validation pending

The owner approved allowing the system keyring unlock prompt and continuing after unlock and the required storage operation succeed; see [accepted ADR 0005](../decisions/0005-keyring-unlock-prompts.md). Cancellation, denial, unlock failure or unavailable/failed storage must stop with a clear storage error and manual Retry. A failed read must not become missing pairing or trigger new pairing. No plain-text fallback or false save success is allowed.

The selected `flutter_secure_storage_linux` 3.0.3 `Secret.hpp` warmup calls `secret_service_unlock_sync` for a locked default collection. Keep the selected plugin; the former strict no-unlock policy no longer requires a native patch or racy metadata preflight. Actual prompt success, cancellation/denial, failure translation and timing still need target-desktop validation. No keyring manipulation or new storage operation was authorized by this policy decision.

## Deadline and daemon cleanup

The operation budget is 120 seconds; bounded cleanup can add time. Dart timeout stops waiting but does not cancel an already-sent daemon operation. BLE device-wide Disconnect cleanup has a one-second best-effort allowance. Therefore closing the client and releasing application single-flight ownership is not proof that every server-side effect has finished. A delayed reply alone does not prove delayed effects; the target BlueZ behavior has not been reproduced. Do not claim strict wall-clock C3 compliance or invent automatic recovery for this unverified concern.

NM cleanup also uses one second per activation/deactivation/deletion step. After activation-path timeout, cleanup depends on the accepted caller binding and volatile behavior, which isolated D-Bus tests do not establish on the real daemon.

## Fixes from offline review

- Network-enabled Pair now preflights writable `da5` before potentially replacing `da0`, not just during subsequent Resume. The missing-capability regression ran red then green.
- Network validity is separate from cleanup settlement: `isActive`/`lost` invalidate Connected promptly, while `ended` completes after cleanup. Retry remains unavailable until cleanup settles. Simulated tests cover loss during verification and loss while deletion is blocked.

## Evidence boundaries

The 2026-11-18 joint network attempt and one manual Retry failed at Wi-Fi. Old output lacked cause; observability corrections now log safe stages/outcomes and explicit managed failures, preserving unexpected errors for reporting. No further real test ran during those corrections. Full automated checks, actual Linux launches and screenshots are recorded in the [connection guide](connection.md) and [evidence](evidence/issue-2/README.md). No overnight camera, host BlueZ/NetworkManager or keyring operation ran. An early HTTP negative-input test attempted TEST-NET documentation address `192.0.2.1` bound to loopback and failed immediately before explicit configuration validation existed. No packet-level observation is claimed. Final tests reject it before client creation and use successful loopback connections only. No camera endpoint was contacted.

Camera AP timing, DHCP/routes, WPA behavior, status schema, real secret-agent persistence, native authorization dialogs and affected failure cases remain hardware/platform checks, not inferred passes.
