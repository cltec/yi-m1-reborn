# Architecture decision records

Use an ADR for a significant architectural choice that future contributors need to understand. Keep feature-level functional and technical specifications in the GitHub issue; link them rather than duplicating the whole issue here.

| ADR | Status | Decision |
| --- | --- | --- |
| [0001](0001-ports-and-adapters.md) | Accepted | Ports and Adapters for multiple native platforms |
| [0002](0002-flutter-dart.md) | Accepted | Flutter/Dart, with platform-independent core and platform adapters |
| [0003](0003-linux-integration-boundaries.md) | Accepted | Narrow Linux integrations and platform-neutral pairing storage |

## Recording a decision

Copy [the template](template.md) to the next sequentially numbered Markdown file and give it a descriptive title. Start as Proposed; mark Accepted only after approval. Record context, the decision, alternatives and consequences. Link the issue and affected documentation when available. No issue is required for the owner-authorized initial documentation scaffold.

Do not rewrite an accepted historical decision to conceal a change. Add a superseding ADR and cross-link both. Update this index in the same change.
