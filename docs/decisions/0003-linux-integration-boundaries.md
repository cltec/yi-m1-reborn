# ADR 0003: Keep Linux integrations narrow and behind application ports

- Status: Accepted; app-exit lifetime amended by [ADR 0004](0004-camera-network-lifetime.md), locked-keyring policy amended by [ADR 0005](0005-keyring-unlock-prompts.md)
- Date: 2026-11-17
- Related issue: [#1 — Open Gallery](https://github.com/cltec/yi-m1-reborn/issues/1)
- Supersedes: The earlier issue-level `nm` 0.6.0 selection; complements [ADR 0001](0001-ports-and-adapters.md) and [ADR 0002](0002-flutter-dart.md).

## Context

The first slice needs Linux BLE, automatic camera Wi-Fi association and remembered pairing storage. The owner wants few dependencies and low total implementation/maintenance complexity, while keeping future Android/iOS adapters independent. Source inspection and host diagnostics do not establish camera compatibility.

The owner initially approved `nm` 0.6.0 for NetworkManager access. It does not expose `AddAndActivateConnection2`, needed for the selected volatile-profile approach; combining a wrapper with direct-call glue added complexity without demonstrated value for this narrow slice.

## Decision

- Use `bluez` 0.9.0 for Linux BLE, confined to an outbound adapter.
- Replace `nm` with a small project-owned NetworkManager adapter over Dart `dbus`, the transport already required by `bluez`. Declare it directly when importing it; resolve a compatible version rather than inventing a new exact pin. Implement only needed calls, state observation and error translation, not the D-Bus protocol or Wi-Fi management itself.
- Use `AddAndActivateConnection2` with `persist="volatile"` for the app-created camera Wi-Fi profile: no disk profile, removal when its connection ends. Do not modify the user's existing profiles. App-exit disconnection and previous-network restoration are not added.
- Supply fresh camera Wi-Fi credentials for connection use only. Do not persist the Wi-Fi password in the app, NetworkManager or a desktop agent. Secret flags and actual agent behavior require separate validation; temporary-profile persistence alone is insufficient evidence.
- Use `flutter_secure_storage` 11.2.0 in the desktop storage adapter behind an application-owned, platform-neutral port. Remember camera identity and pairing key/token, not the Wi-Fi password. A locked/unavailable keyring stops the attempt with a clear error and manual Retry, without plain-text fallback or new pairing.

No Flutter, D-Bus, BlueZ or keyring types belong in domain/application contracts. Future platforms may use different integrations; no mobile stubs are required now.

## Alternatives considered

| Alternative | Assessment |
| --- | --- |
| `nm` plus missing-method D-Bus glue | Initially approved, then superseded by the owner in favor of fewer wrappers and a narrow adapter |
| Only `nm` unsaved-profile APIs | Would require separate cleanup to satisfy removal on connection end |
| Native C++ plugin or custom D-Bus protocol | Adds native glue or protocol maintenance without an established need; reuse the existing Dart transport |
| Broad cross-platform integration framework now | Does not establish platform compatibility and adds scope before the first verified slice |

## Consequences

The project owns a small NetworkManager integration surface and its tests. Removing a wrapper does not remove the underlying D-Bus dependency. MPL-2.0 terms for `bluez`/`dbus` and BSD-3-Clause terms for `flutter_secure_storage` need distribution review; the project license remains undecided.

Linux keyring builds require `libsecret-1-dev`, absent at the recorded inspection. Nothing was installed. Dependency resolution, build, keyring error handling, pairing reuse, fresh credential retrieval and volatile-network behavior remain untested.

The owner-approved prerequisite order in issue #1 must establish these facts before the production technical specification is finalized. Each probe needs its applicable approval, and pairing needs explicit authorization. Failed evidence requires a revised plan, not silent fallback to persistent profiles or replacement pairing.

## References

- [Environment and inspected package sources](../development/environment.md)
- [Architecture boundaries](../architecture/README.md)
- [Fresh-session validation handoff](../development/validation-handoff.md)
