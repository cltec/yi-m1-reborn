# ADR 0002: Use Flutter and Dart

- Status: Accepted
- Related issue: [#1 — Open Gallery](https://github.com/cltec/yi-m1-reborn/issues/1)
- Supersedes: None; complements [ADR 0001](0001-ports-and-adapters.md).

## Context

YI M1 Reborn targets Linux desktop first, with Android and iOS later. The owner selected Flutter/Dart during issue #1 planning. On 2026-11-17 the owner confirmed Pop!_OS 22.04 LTS as the first environment instead of the previously assumed Ubuntu 26.04 target. No application or camera compatibility test has run.

## Decision

Use Flutter for presentation and Dart for the application. Preserve the accepted Ports and Adapters boundaries: domain/application remain independent of Flutter, plugins and platform I/O. The composition root selects concrete adapters.

The framework selection is accepted. SDK versions, BLE/Wi-Fi integrations, keyring library, state management and test tooling were left open by that selection; this decision does not authorize implementation before issue #1's remaining technical approval.

On 2026-11-17, following inspection of the installed SDK, the owner approved pinning **Flutter 3.44.4 stable with its bundled Dart 3.12.2** for issue #1, without an SDK upgrade. Subsequent library selections are recorded in the [environment record](../development/environment.md). The owner subsequently approved standard Flutter test tooling for BDD without a separate Gherkin runner; see the [testing guide](../development/testing.md#use-standard-flutter-tooling-for-bdd) for boundaries and remaining gaps. No application tests have run.

## Alternatives considered

Leaving the framework undecided was the scaffold's earlier position. The owner's explicit Flutter/Dart selection resolves that question. No comparative framework benchmark or prototype was performed; this ADR records the choice, not an evidence-backed claim of superiority.

## Consequences

UI and shared application work can use one language across the intended platforms. Shared code does not establish platform compatibility: OS permissions, networking and storage still need adapters and validation. Pairing secrets use an application-owned, platform-neutral storage port with a desktop-keyring implementation for issue #1; future Android/iOS implementations may differ and are not required now. No unused platform stubs should be created.

The first implementation must establish reproducible SDK and test commands and exercise the actual target desktop application. Ubuntu 26.04, Android and iOS remain unverified.

## References

- [Project context](../context.md)
- [Architecture](../architecture/README.md)
- [Workflow](../development/workflow.md)
