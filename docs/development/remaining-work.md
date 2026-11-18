# Remaining Gallery delivery work

The owner requested publishing the current implementation as a development snapshot and a **draft PR**, not completing or merging #1/#2/#3. Camera integration, required hardware evidence and missing native UI evidence remain open. Offline completion is not hardware completion.

## Issue hierarchy

[Parent #1](https://github.com/cltec/yi-m1-reborn/issues/1) contains [connection #2](https://github.com/cltec/yi-m1-reborn/issues/2), [filename listing #3](https://github.com/cltec/yi-m1-reborn/issues/3) and final acceptance #13. The following are actual GitHub sub-issues, not only text links.

| Parent | Follow-up | Outcome still required |
| --- | --- | --- |
| #2 | [#5 — Diagnose and fix the real camera Wi-Fi connection failure](https://github.com/cltec/yi-m1-reborn/issues/5) | As an owner with saved pairing, I want automatic camera Wi-Fi association to succeed or report the actual failed step, so I can reach a verified connection without blind retries. |
| #2 | [#6 — Validate native keyring unlock, cancellation and storage failures](https://github.com/cltec/yi-m1-reborn/issues/6) | As an owner, I want keyring unlock to continue my connection only after storage succeeds, with safe recovery on denial or storage failure. |
| #2 | [#7 — Verify camera Wi-Fi credentials are not persisted by NetworkManager or agents](https://github.com/cltec/yi-m1-reborn/issues/7) | As an owner, I want camera Wi-Fi credentials used only for the current connection, with only pairing material remembered in the application keyring. |
| #2 | [#8 — Verify temporary camera Wi-Fi disconnect and cleanup on close or crash](https://github.com/cltec/yi-m1-reborn/issues/8) | As an owner, I want the desktop to disconnect from the app-owned camera network when the app closes or crashes, without changing my existing profiles or saved pairing. |
| #2 | [#9 — Enforce and verify the total 120-second connection failure deadline](https://github.com/cltec/yi-m1-reborn/issues/9) | As an owner, I want a stalled connection attempt to end within the agreed 120 seconds and offer safe manual Retry, including cleanup rather than an unbounded wait. |
| #3 | [#10 — Connect Gallery to real GetFileList with complete JPEG and RAW pagination](https://github.com/cltec/yi-m1-reborn/issues/10) | As an owner, I want the same Gallery workflow used offline to list every camera photo filename through the verified camera session, without downloading originals. |
| #3 | [#11 — Establish camera timestamp semantics and verify filename ordering](https://github.com/cltec/yi-m1-reborn/issues/11) | As an owner, I want Gallery ordering to reflect usable camera-provided times without invented capture-time claims, with undated filenames ordered last. |
| #3 | [#12 — Finish native Gallery loading and empty-state visual evidence](https://github.com/cltec/yi-m1-reborn/issues/12) | As a Linux user, I want readable loading and empty Gallery states at both agreed sizes, with reviewable evidence from the actual app. |
| #1 | [#13 — Complete joint real-camera Gallery acceptance and review handoff](https://github.com/cltec/yi-m1-reborn/issues/13) | As an owner, I want the combined connection and filename-listing journey verified on my actual camera before the parent feature is called complete or merged. |

## Work that can proceed offline

Deadline regression work, source-informed real-list adapter implementation and native loading/empty UI captures can proceed without a camera where their own prerequisites permit. Their hardware claims remain pending. Native captures need an accessible desktop; do not change lock/security policy to obtain them.

The actual Wi-Fi cause needs a joint diagnostic run. Keyring validation and credential/profile inspection need separately approved safe host scope. Real listing/pagination/timestamps and combined acceptance need the camera and suitable known card coverage. Do not assume all remaining work is validation-only or blocked on hardware.

[Issue #4](https://github.com/cltec/yi-m1-reborn/issues/4) remains the explicitly deferred competing-route protection, not a prerequisite for this delivery. Record the tested network setup and source-binding limitation in eventual hardware evidence.

## Publication and review

The combined publication branch is `dev/gallery-offline-integration`, based on the local #2 baseline `4b43b2c` and offline #3 work together at the owner's explicit request. The earlier feature branches remain local reference points. A draft snapshot does not waive the normal one-slice review/PR workflow or hardware merge gate. It is not ready to merge; keep #1/#2/#3 and follow-ups open until their acceptance is met. No closing keywords are used to auto-close incomplete issues.

Current checks: 165 automated tests and five simulated Linux integration journeys pass; analysis, format and whitespace checks pass. Populated/error native Gallery screenshots were inspected at both sizes. Loading/empty native evidence is pending #12. Real BLE restart reuse passed earlier, but real Wi-Fi/status failed and its cause is unknown. Synthetic catalogs do not prove GetFileList, paging or timestamp semantics.

Use the [connection guide](connection.md), [offline Gallery guide](gallery-offline.md) and [validation handoff](validation-handoff.md) for reproducible commands and evidence boundaries.
