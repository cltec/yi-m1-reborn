# Documentation instructions

Read the root [AGENTS.md](../AGENTS.md) first. These rules apply within `docs/`.

## Sources of truth

| Topic | Canonical location |
| --- | --- |
| Current scope, terminology and unanswered product decisions | [context.md](context.md) |
| Development process | [development/workflow.md](development/workflow.md) |
| Test strategy and completion evidence | [development/testing.md](development/testing.md) |
| Architecture explanation | [architecture/README.md](architecture/README.md) |
| Significant decisions and their rationale | [decisions/README.md](decisions/README.md) |
| Historical sourced camera investigation | [research/README.md](research/README.md) |
| Feature-specific functional/technical spec and acceptance criteria | The feature's approved GitHub issue |

## Authoring rules

- **CRITICAL:** Apply the root [AGENTS.md](../AGENTS.md) mandatory "show, don't tell" rule. Do not explain instruction compliance or praise the response itself; stating uncertainty is allowed.
- Write short, concrete English. Use the glossary in context.md consistently.
- Keep one primary reader need per page: how-to for tasks, reference for facts, explanation for how/why, tutorials only for tested learning paths.
- Document implemented behavior with code. Label planned designs, proposals, untested behavior and open questions explicitly.
- Verify documented user steps against the running application. For safe, inspected screenshots, storage, alternative text and image maintenance, follow [testing guidance](development/testing.md#reuse-screenshots-in-documentation).
- Explain important constraints, trade-offs and rejected alternatives, not just file names. Link the relevant issue and ADR rather than duplicating them.
- When an issue changes, update any affected maintained docs and tests in the same slice. Record scope changes in the issue and seek approval rather than silently expanding it.
- Preserve historical research provenance. Add dated corrections or a current-context pointer instead of rewriting old uncertainty into a fabricated past fact.
- Cite URLs and inspected revisions for external protocol claims. Separate source inspection, simulated tests and real-camera tests.
- Use relative links within the repository. Verify linked files and commands actually exist; no placeholder build commands.
- Do not publish proprietary binaries/decompiled implementation, secrets or personal photos. Sanitized observations and derived interoperability facts belong in the docs; raw artifacts stay outside git.
- Maintain the [documentation index](README.md) and applicable ADR index when adding/removing pages. Keep this file a rule index, not a second product specification.
