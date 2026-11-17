# Architecture: Ports and Adapters

## Decision and current state

**Ports and Adapters is accepted for yi-m1-reborn. No application exists yet.** This page explains the boundaries the future application must respect, not an implemented package layout. [ADR 0001](../decisions/0001-ports-and-adapters.md) records why this approach was chosen.

The first target is **Pop!_OS 22.04 LTS** (Ubuntu 22.04-based Linux desktop), with Android and iOS later. **Flutter/Dart is selected** in [issue #1](https://github.com/cltec/yi-m1-reborn/issues/1); see [ADR 0002](../decisions/0002-flutter-dart.md). Selected adapter libraries are recorded below; UI state management, broader OS baselines and runtime commands remain open. Universal direct-camera web support is not a requirement.

For issue #1, use standard Material 3 controls without a custom theme or design system. Later app-wide styling can use Flutter `ThemeData` at the presentation boundary; it must not introduce theme dependencies into camera or application logic.

[ADR 0003](../decisions/0003-linux-integration-boundaries.md) records the approved Linux integration and storage choices, including why `nm` was replaced.

The [project context](../context.md) defines product scope. The target camera firmware is user-reported **3.2-int**; this is not our own hardware validation. Existing [research](../research/README.md) provides protocol evidence, not a tested implementation contract. Older research descriptions of undecided product scope are historical; the context and accepted decisions govern new work.

## Why the boundaries matter

The camera uses BLE for pairing and Wi-Fi setup, local HTTP for gallery/control, and a separate UDP path for live view. These transports and the operating system should not dictate how gallery selection, reconnect policy or download outcomes are represented. Ubuntu, Android and iOS differ in permissions, network joining, routing and file destinations even when they speak the same camera protocol.

Ports and Adapters separates those changes. It also permits application behavior to be tested without a camera, desktop UI or mobile runtime. The cost is some translation and explicit contracts at the boundaries; we keep those contracts small and derive them from real features.

## Accepted dependency rules

Dependencies point inward. Runtime calls may travel outward through an injected port, but the core never imports its implementation.

| Boundary | Owns | Must not depend on |
| --- | --- | --- |
| Domain | Pure product rules and values: media identity, original-versus-preview distinction, selection rules and validated state transitions where needed | Flutter/widgets, plugins, HTTP/GATT/socket types, filesystem handles, persistence or OS APIs |
| Application | Use-case inputs/results, workflow orchestration and application-owned inbound and outbound port contracts | Concrete UI, system services, camera transport clients or storage implementations |
| Inbound presentation adapters | User actions, presentation state and mapping use-case results to views | Direct camera/file access that bypasses a use case |
| Outbound adapters | Camera protocol, OS access, saved connection data and destination storage; translation into application-owned values/errors | Product workflow decisions that belong in a use case |
| Composition root | Concrete construction, injection and resource ownership for a platform entry point | Business rules |

The application depends on the domain. Both use technology-independent types; neither imports Flutter nor system I/O libraries. The domain uses only ordinary language/standard-library value types and domain-owned abstractions. Immutable values and state transitions keep framework lifecycle and shared mutable state out of domain rules.

An inbound port expresses a use case, such as browsing the gallery or downloading a selection. A presentation adapter invokes it and renders the result. An outbound port expresses a required capability, such as accessing camera media or saving original bytes. It is not a generic wrapper for a plugin, HTTP client or every pure helper. These examples are conceptual responsibilities, not approved interface names or a complete API inventory.

The composition root is the only place that selects concrete adapters and wires them to use cases and presentation. Each platform entry point has one wiring location. No service locator or platform check belongs in the domain/application core.

## Planned responsibility mapping

The following mapping guides future slices. It does not mean these components or their interfaces already exist.

| Behavior | Application responsibility | Adapter responsibility |
| --- | --- | --- |
| Remembered connection | Attempt authorized reuse, report progress/cancellation, and require a user decision if new pairing is needed; own a platform-neutral storage port | Remember camera identity and pairing key/token through the storage port; retrieve fresh Wi-Fi credentials per connection without persisting the camera Wi-Fi password. Use a desktop-keyring adapter for issue #1; future Android/iOS adapters may use different stores. Implement M1 BLE session exchange and OS connection operations separately |
| Connection status and Disconnect | Expose connection state and stop an operation when the user disconnects | Report link changes and release concrete connections/subscriptions |
| New pairing | Require explicit approval before initiating a pairing that may replace an old one; represent camera confirmation/refusal | Implement wire handshake, notifications and session payloads; surface camera confirmation state without logging tokens |
| Gallery | Establish a usable connection, list media, request thumbnails/preview and maintain user selection | Map local HTTP listing/file responses into media values; keep request spelling, pagination and encoding quirks at the camera edge |
| Selected originals | Orchestrate selected JPEG/RAW downloads, progress, cancellation and per-file outcomes; never substitute preview bytes for originals | Stream unchanged original bytes and save through the destination adapter; handle partial files and platform access failures |
| Live | Start/stop the feed with use-case lifecycle and cancellation; request a remote shot as a separate user action | Issue camera control requests; receive UDP packets, assemble valid frames and release sockets; presentation decodes/renders frames without exposing UI image types to the core |

A remote shot stays on the camera; it does not automatically download or save the live feed locally. Gallery remains separate from Live. Do not assume browsing needs UDP reception; validate any required camera mode before introducing that coupling. Unsupported RAW previews must be reported rather than silently downloading a large original.

Automatic remembered connection is a product goal, **not permission to pair again silently**. Source reports say new pairing can replace the camera's stored pairing. Camera-screen approval remains required for new pairing, and actual remembered-session reuse needs validation on the user's body. A failed resume must stop at a clear user choice, not fall back to destructive or repeated pairing attempts. Connection failure alone is not proof of invalid pairing; no time-based expiry has been established. In issue #1, Retry reuses the remembered connection and any re-pairing requires explicit approval. CRC32 in the recovered handshake is not modern cryptographic authentication. See [pairing evidence](../research/protocol-prior-art.md#handshake-reproduced-from-source-not-tested-here) and [validation safety](../research/device-validation.md#safety-boundaries).

## Share protocol logic, isolate operating systems

Pure M1 request/response codecs, handshake payload calculations and UDP frame assembly can be shared across platforms if the eventual language/runtime permits it. They belong to the camera protocol adapter, not the domain merely because they are pure. Wire-level sequencing also stays there; the application owns the user workflow across capabilities.

OS BLE access, permissions, camera-network joining/routing, secret persistence and file/media saving need platform-specific adapters or integration. Shared HTTP/UDP code is possible, but it does not establish identical OS behavior. Flutter widgets, plugin objects and platform channels stay at these edges. For issue #1, the owner approved `bluez` 0.9.0 inside the Linux BLE adapter and a narrow project-owned NetworkManager adapter over `dbus` for Linux networking, superseding the earlier `nm` 0.6.0 wrapper selection. Reuse the D-Bus transport already required by `bluez`, declaring it directly when imported. Keep custom code to required NetworkManager calls, state observation and error translation, not D-Bus protocol or Wi-Fi management. Library/platform types must not leak into the core. Future mobile adapters may use different libraries. This library choice does not establish camera compatibility. Pairing storage is an application-owned, platform-neutral capability, not a keyring API wrapper exposed to the core. The owner approved `flutter_secure_storage` 11.2.0 inside the desktop storage adapter; its Linux implementation uses `libsecret`. Plugin types and storage exceptions must be translated at that boundary; runtime behavior remains unvalidated. Only the desktop implementation is needed now; do not generate unused mobile stubs. A shared protocol implementation must not become a reason to promise untested Android/iOS compatibility.

The [protocol research](../research/protocol-prior-art.md) and [original-app analysis](../research/original-app-analysis.md) remain the wire references. Firmware-specific write modes, pagination, network behavior, HTTP concurrency and RAW preview availability are validation questions, not universal constants to copy into the core.

## Errors and resource ownership

Outbound adapters translate platform/protocol failures into application-level outcomes, such as permission denied, pairing refused, connection lost, unsupported preview or save failed. They must distinguish transport success from camera-command success. Preserve the diagnostic cause at the edge with secrets and private paths redacted; do not leak plugin exceptions or raw responses into use-case contracts.

Application use cases decide recovery, cancellation and safe retry policy. Presentation explains the outcome and asks for required user action. For issue #1, a locked or unavailable keyring must stop the connection attempt with a clear storage error and manual Retry, not become “no remembered camera” or trigger new pairing. Do not fall back to plain-text secrets; failed persistence must not be reported as successful remembered setup. Do not blindly retry pairing or a remote shot when the outcome is unknown: either can have effects the client has not observed. Concrete adapters own cleanup of subscriptions, sockets and partial writes; the use case owns the operation's lifetime through its capability contract. For issue #1, the Linux network adapter must keep its app-created camera Wi-Fi profile in memory and arrange removal when that network connection ends, without changing existing user profiles. Remembered pairing remains in the separate keyring adapter; removing the temporary network profile must not erase remembered pairing. Supply Wi-Fi credentials to NetworkManager only for connection use, without a separately persisted NetworkManager/desktop-agent copy. The Linux network adapter owns the necessary secret-supply flags and agent behavior; this must be validated independently of temporary-profile persistence.

## Grow through working vertical slices

Prefer the smallest solution that meets the slice: use Dart/Flutter SDK or existing platform facilities where practical, and add a package only when it reduces total implementation and maintenance complexity. Avoid dependency proliferation, but do not replace mature protocol infrastructure with hand-written equivalents merely to reduce package count.

Do not implement all layers first or generate an interface catalog and empty packages. Begin with an approved story and BDD acceptance scenarios, then use incremental TDD. Start with one small, observable user outcome, define only its needed rules and ports, then connect the needed adapters through presentation. For issue #1, complete its ordered prerequisite validation and obtain final production specification approval first; fakes cannot satisfy those prerequisite checks. Expand that same path with real evidence before adding another feature. Connection/gallery/original download and Live can grow independently; the product scope does not require implementing all capabilities at once.

Test domain rules directly, use cases with small port fakes, protocol adapters with sanitized fixtures, and OS adapters against their real boundaries. Add authorized hardware checks for pairing, original-byte integrity, UDP behavior and reconnect recovery; source evidence and fakes do not replace them. Later Android/iOS adapters must satisfy the same capability behavior and receive their own platform/hardware tests. The [development workflow](../development/workflow.md) governs story approval and slice delivery. The [testing guide](../development/testing.md) describes the testing approach; [device validation](../research/device-validation.md) records safety limits and unresolved hardware questions.
