# ADR 0001: Use Ports and Adapters

- **Status:** Accepted
- **Later clarification (2026-11-17):** [ADR 0002](0002-flutter-dart.md) records the subsequent Flutter/Dart selection. [Project context](../context.md) records Pop!_OS 22.04 as the first target. The original context below is historical; the dependency decision remains accepted.
- **Date:** 2026-11-16
- **Scope:** yi-m1-reborn application architecture; no application implementation exists yet

## Context

The user chose Ports and Adapters for a replacement companion app for the YI M1. Ubuntu Linux Desktop is first; Android and iOS follow. Flutter is a candidate, not a selected dependency. Universal direct-camera web support is not required.

The agreed workflows are Gallery with automatic remembered connection, thumbnails/preview and selected JPEG/RAW original downloads, plus Live with a feed and remote shot. Remote shots remain on the camera. The user's target firmware is **3.2-int**, but this repository has not validated the physical device.

[Research](../research/README.md) supports BLE pairing/Wi-Fi setup, local HTTP gallery/control and separate UDP live view. Those transports are distinct from the product workflow. Operating systems also differ in BLE access, permissions, networking and save destinations. Camera-side approval and possible replacement of an existing pairing make connection recovery a user-policy concern, not merely a transport retry.

## Decision

Keep domain rules and application use cases independent from presentation, camera protocol and operating-system implementations. Dependencies point inward:

- The domain owns pure rules and values, without frameworks or I/O.
- The application owns use cases and capability contracts, depending only on domain and technology-independent types.
- Inbound adapters translate user actions into use-case calls and results into presentation.
- Outbound adapters implement camera access, OS integration and persistence through application-owned ports.
- A composition root at each platform entry point owns concrete wiring and resource construction.

Share pure M1 protocol logic where practical, but keep it at the camera adapter boundary. Isolate OS-specific BLE, network, permission, secret-storage and file-saving behavior. Do not expose Flutter/plugin/system types in the core or put gallery workflows in transport adapters.

Derive small ports from one working vertical slice at a time. This decision does not approve a package layout, a full interface inventory, or a layer-first implementation plan. The [architecture explanation](../architecture/README.md) gives the planned responsibility mapping and error boundaries.

## Why this choice

The first implementation must be practical on Ubuntu without binding later mobile clients to desktop APIs. Separating core behavior lets us test selection, connection policy and download outcomes without live hardware. Separate protocol and OS adapters allow reuse of validated M1 behavior while making platform-specific uncertainties visible. Explicit use cases also provide a clear place to prevent silent re-pairing, preview-for-original substitution and unsafe retries.

The user's explicit choice establishes the architecture now. It does not establish hardware compatibility, a language, Flutter, plugin choices, UI state management, minimum OS versions or application commands.

## Alternatives considered

| Alternative | Advantage | Why not selected |
| --- | --- | --- |
| UI/plugin-driven application | A short path to a first screen and device experiment | Couples connection policy and gallery workflows to a framework/platform; hard to test without those dependencies or reuse on later targets |
| Separate native application per OS | Direct access to each OS's APIs | Duplicates workflow/protocol behavior and recovery policy unless boundaries are deliberately shared; native adapters remain an option within this decision |
| Large layer-first scaffold | Makes every anticipated component visible early | Invents unproven contracts and empty structure before a working slice; increases maintenance without proving camera behavior |

These are design alternatives, not claims that prototypes or comparative benchmarks have been run. Adapting licensed prior art remains possible behind the same boundaries; this ADR does not select a fork or authorize copying proprietary app code.

## Consequences

- Core behavior can be exercised with simple fakes; protocol and OS adapters require separate integration tests and authorized hardware checks. See [testing](../development/testing.md).
- Translation and wiring add some code. Keep abstractions tied to real capabilities so this cost stays small.
- A shared protocol implementation does not remove permission, routing, storage or lifecycle differences. Later Android/iOS support needs its own validation.
- Remembered-session failure must not silently trigger replacement pairing. New pairing requires explicit user approval and camera-screen confirmation. Pairing persistence, original-file integrity and UDP behavior remain unverified on the target camera.
- Firmware quirks stay at the camera boundary. No firmware changes, destructive commands or automatic clock changes are justified by this architecture.
- Revisit implementation choices when a vertical slice produces evidence; change the accepted dependency rules only through a later decision record.

## Related documents

- [Project context](../context.md): current scope and open choices.
- [Architecture](../architecture/README.md): accepted boundaries and planned responsibility mapping.
- [Research](../research/README.md): evidence and limits, including historical undecided scope.
- [Device validation](../research/device-validation.md): authorization and safety boundaries.
