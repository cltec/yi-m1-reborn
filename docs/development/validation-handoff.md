# Resume issue #1 prerequisite validation

Use this handoff to prepare the first readiness check in a fresh session. Related feature: [issue #1](https://github.com/cltec/yi-m1-reborn/issues/1).

## Starting state

- Documentation/research only. No application, validation probe or project test setup exists.
- Product behavior, stack/library choices and the V1–V8 dependency order are approved. The final production technical specification is **not approved**.
- The V1 read-only readiness procedure is proposed, **not yet approved or executed**. The owner paused execution to consolidate and publish these documents. Commit/push authorization does not authorize readiness checks, probe code, installations or camera operations.
- Earlier host inspection is recorded in [environment](environment.md); recheck relevant observations rather than treating them as current. It did not establish camera compatibility.
- On 2026-11-17 the owner said the camera was beside this PC and did not think it remembered an old pairing. Reconfirm availability in the new session. Existing pairing is **unknown**, not verified absent; new pairing could replace it.
- Test-card inventory, safe sample availability and backup status are not confirmed. Do not prepare the card by deleting files or changing camera settings.

## Approved dependency order

The issue holds task acceptance/evidence details. None of these validation tasks is complete.

| Task | Depends on | Result needed |
| --- | --- | --- |
| V1 — Safe validation setup | None | Approved procedure, relevant tools/access, safe camera/card preconditions and separately approved minimal probes |
| V2 — Camera discovery/GATT | V1 | Actual identifiers and required capabilities, without pairing or camera Wi-Fi activation |
| V3 — Authorized pairing/session | V2 | Camera approval and verified session; retain required pairing material privately in the keyring |
| V4 — Remembered reuse/fresh credentials | V3 | Reuse without new pairing; verify needed identity/key/token and retrieve current Wi-Fi credentials |
| V5 — Automatic Wi-Fi/reachability | V4 | Association, routing, temporary profile lifecycle and no separately persisted Wi-Fi password |
| V6 — Read-only photo-list behavior | V5 | Known-card evidence for requests, pagination, JPEG/RAW representation and timestamps |
| V7 — Final production specification | V1–V6 | Evidence-backed contracts, fixtures and validation plan; explicit owner approval |
| V8 — Gallery implementation/acceptance | V7 | Incremental BDD/TDD, actual UI checks and end-to-end hardware evidence |

A failed or pending prerequisite blocks dependent work. Research and fakes may inform probes, but do not satisfy these checks. Earlier probe success does not replace acceptance of the final production integration. All camera operations remain subject to [safety boundaries](../research/device-validation.md#safety-boundaries).

## Fresh-session procedure

1. Read root/scoped agent rules, [context](../context.md), [workflow](workflow.md), [testing](testing.md), [architecture](../architecture/README.md), ADRs and issue #1 including comments. Check `git status --short --branch` before editing.
2. Confirm that this is still the target PC/camera setup. Ask one question at a time. Do not infer permission from camera availability or earlier product decisions.
3. Present the proposed V1 read-only pass below and obtain approval before execution.
4. Run only the approved host checks, record actual results and report missing prerequisites. Do not mark all of V1 complete from tool availability alone.
5. Prepare the smallest separately reviewable probe proposal. Stop for authorization before writing/executing probe code, installing prerequisites, scanning, pairing, joining Wi-Fi or exercising keyring writes. Do not proceed to V2 until V1's required readiness evidence is satisfied.
6. Update issue #1 and affected docs with results, limitations and the next blocked/ready task. Do not finalize the Gallery production specification before V1–V6 evidence.

## Proposed V1 read-only pass

This is a plan, not a record of execution:

- Recheck pinned Flutter/Dart availability, Linux build prerequisites, active BlueZ/NetworkManager services and current authorization. Prior inspection commands and versions are in the environment record. Run Flutter diagnostics sequentially to avoid its startup-lock contention; diagnostics may refresh SDK caches or contact services, but must not upgrade/configure the SDK or alter desktop settings.
- Use version queries, package inventory, service/property reads and permission queries. Do not enumerate unrelated saved profiles, request secrets, scan, restart services, change radio state, switch networks or modify authorization policy.
- Recheck only whether Secret Service is present, not whether personal secrets can be read. The earlier missing `libsecret-1-dev` is a potential build prerequisite to report, not permission to install it. Keyring read/write and locked/unavailable tests need a separate approved, safely scoped probe.
- Ask about existing pairing and safe known card contents/backups. Record uncertainty. No need to disclose photos, passwords, tokens, device addresses or serial numbers.
- Propose a minimal validation workspace and exact probe scope/commands, prerequisites and expected outcomes. No new dependencies, project scaffolding, UI implementation or production adapters in this read-only pass.

Output: a sanitized readiness report separating observed results, missing prerequisites, unresolved preconditions and the next approval request. V1 remains pending until its required setup/probe evidence is complete.

## New-session starting prompt

> Resume issue #1 at V1 using `docs/development/validation-handoff.md`. Read the repository guidance and current issue, confirm the working tree, and prepare the read-only readiness check for approval. The V1–V8 order is approved, but no camera checks, probes, installations or production implementation are authorized yet. Ask one question at a time; record agreed decisions and actual results in the issue and docs.
