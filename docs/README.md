# Documentation

The repository contains documentation, camera research, an in-progress Linux Flutter connection and offline Gallery filename-listing development through application ports. Joint tests verified BLE-session reuse after app restart. Full Wi-Fi/HTTP connection is implemented against simulated boundaries and still needs decisions and hardware validation.

## Start here

- [Project context](context.md): confirmed product scope, terminology and open decisions.
- [Contributor guide](../CONTRIBUTING.md): how to begin work.
- [Agent instructions](../AGENTS.md): compact entry point for AI contributors.

## How-to guides

- [Develop Gallery offline](development/gallery-offline.md): simulated camera composition, shared application flow and final integration limits.

- [Develop the camera connection](development/connection.md): setup, verified checks, pending decisions and jointly supervised camera tests.

- [Development workflow](development/workflow.md): discuss, specify, implement and review a vertical slice.
- [Resume prerequisite validation](development/validation-handoff.md): approved task order and proposed V1 readiness check for a fresh session.

## Reference

- [Remaining Gallery work](development/remaining-work.md): linked sub-issues and draft-publication limits for #1/#2/#3.

- [Testing strategy](development/testing.md): BDD/TDD boundaries and validation evidence.
- [First desktop environment](development/environment.md): measured tools, services and permission limits for issue #1.
- [Connection validation blockers](development/connection-blockers.md): routing, network lifetime, keyring and cleanup limits before real-network testing.
- [Camera research](research/README.md): sourced hardware, app and protocol findings.

## Explanations and decisions

- [Architecture](architecture/README.md): how Ports and Adapters supports multiple platforms.
- [Architecture decision records](decisions/README.md): accepted decisions and their reasons.

Feature specifications live in approved GitHub issues. These documents explain current scope, implementation and rationale; they are maintained with code rather than copied wholesale from issues. Initial research is a dated snapshot: current user-confirmed details take precedence in [context](context.md).
