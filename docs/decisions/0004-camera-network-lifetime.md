# ADR 0004: Bind the temporary camera network to the app process

- Status: Accepted — owner approved disconnection on app close or crash
- Date: 2026-11-17
- Related issue: [#2 — Camera connection](https://github.com/cltec/yi-m1-reborn/issues/2)
- Amends: [ADR 0003](0003-linux-integration-boundaries.md), which does not add app-exit disconnection

## Context

The NetworkManager adapter creates a volatile profile. Activation may succeed even if the app's D-Bus wait times out before the reply supplies the owned profile/active paths. Without those paths the app cannot explicitly remove just that activation. Closing a D-Bus client alone does not normally cancel NetworkManager activation.

The NetworkManager 1.36 API offers `bind-activation="dbus-name"`: release the activation when the calling bus name disappears. Together with `persist="volatile"`, this provides daemon-owned cleanup on a lost caller. It also means closing/crashing the app disconnects its camera Wi-Fi connection. That is a user-visible change from ADR 0003, not merely a transport detail.

## Decision

Use `bind-activation="dbus-name"` with the approved volatile profile. Keep the owning client alive while connected. Explicitly deactivate/delete only the owned paths on failure, connection end or normal disposal. On timeout, allow one second per cleanup operation, then close the owned client; the daemon binding is the fallback for an activation whose reply never arrives.

The owner approved disconnection on app close or crash: “if the app is closed or it crashes, the device should disconnect from the camera.” The guarded adapter and isolated tests implement the selected behavior. Real close/crash disconnection and owned-profile cleanup still need validation. No real NetworkManager activation has tested it. Competing-route protection is deferred to [issue #4](https://github.com/cltec/yi-m1-reborn/issues/4), not a prerequisite for #1/#2/#3. [ADR 0005](0005-keyring-unlock-prompts.md) resolves keyring unlock policy; native validation remains pending. This decision does not authorize a hardware/network run.

## Alternatives and consequences

- Volatile alone preserves the previous scope but cannot guarantee bounded explicit cleanup for a successful activation whose reply never returns. It needs another agreed ownership/recovery policy, not deletion of arbitrary matching profiles.
- Waiting indefinitely for activation paths prevents a bounded failure/Retry result.
- Persistent profiles, modifying user profiles and silently selecting an existing camera profile violate the approved privacy/ownership boundaries.

This decision adds app-exit disconnection, but not manual Disconnect, automatic recovery or previous-network restoration. Real NetworkManager/desktop-agent password persistence and connection-end removal still need separate checks. `psk-flags=2` is a requested no-save policy, not observed proof.

## Reference

[NetworkManager 1.36 AddAndActivateConnection2](https://networkmanager.dev/docs/api/1.36.0/gdbus-org.freedesktop.NetworkManager.html): `persist` and `bind-activation` options. The documented value is `dbus-name`, not `dbus-client`.
