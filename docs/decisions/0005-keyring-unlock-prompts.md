# ADR 0005: Allow keyring unlock prompts

- Status: Accepted
- Date: 2026-11-17
- Related issue: [#2 — Camera connection](https://github.com/cltec/yi-m1-reborn/issues/2)
- Amends: [ADR 0003](0003-linux-integration-boundaries.md), only its stop-on-locked policy

## Context

The selected Linux secure-storage plugin can ask Secret Service to unlock the keyring and continue. It offers no no-prompt option. A separate lock-state check cannot guarantee stop-on-locked behavior because the keyring may lock between checking and accessing it.

## Decision

The owner chose “prompt and continue.” Allow the system keyring unlock prompt when storage is needed. Continue the same connection attempt only if unlock and the required read or verified write succeed. An already unlocked keyring needs no prompt.

If unlock is canceled, denied or fails, or storage remains unavailable or fails, stop with a clear storage error and manual Retry. Do not treat a failed read as missing pairing, initiate new pairing because of it, fall back to plain-text storage or report an unsuccessful save as successful.

Keep `flutter_secure_storage` 11.2.0 and its existing adapter. Do not add a no-prompt preflight, new plugin or native patch for the former stop-on-locked policy.

## Consequences

The policy mismatch is resolved, not the platform validation. Actual unlock success, cancellation/denial and unavailable storage still need separately scoped target-desktop checks. Mocked channel results do not prove native dialog behavior or error translation. This decision does not authorize locking the owner's keyring or running camera/network tests.

The existing 120-second operation budget is unchanged. Prompt timing and timeout behavior still need validation; no indefinite-wait exception was approved.

## References

- [Storage and other connection validation limits](../development/connection-blockers.md)
- [Linux integration decision](0003-linux-integration-boundaries.md)
