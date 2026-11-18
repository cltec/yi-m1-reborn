# Contributing

Start with [project context](docs/context.md), the [development workflow](docs/development/workflow.md), [architecture](docs/architecture/README.md) and [testing strategy](docs/development/testing.md). AI agents must also read [AGENTS.md](AGENTS.md).

## Before implementing a feature

Discuss one question at a time. Record each resolved point in its issue and affected maintained documents as soon as it is agreed. Agree an actionable user story and record functional/technical specifications and BDD acceptance scenarios in a GitHub issue. Obtain approval before implementation. Use the [feature issue form](.github/ISSUE_TEMPLATE/feature.yml) as a checklist, not as approval or a reason to create issues automatically.

Implement one small end-to-end-testable vertical slice per issue-linked feature branch and pull request. Write tests before production behavior using incremental red–green–refactor. Update documentation in `docs/` with the code, including reasons for significant decisions.

For every UI-touching feature, agree expected screens and important states before coding. Launch and exercise the actual target application, capture and visually inspect screenshots, and embed the evidence in the PR. See the [testing guide](docs/development/testing.md#visually-verify-every-ui-change) for coverage, captions and documentation-image rules. Verify documented user steps against the running application.

The implementing agent prepares the branch, runs checks, updates docs and opens the PR. The owner reviews, approves and merges it. The [pull request template](.github/pull_request_template.md) records acceptance coverage, visual checks and hardware evidence. Hardware-dependent work is not complete until validated with the owner's camera on the agreed target desktop (Pop!_OS 22.04 for issue #1). Do not claim an automated fake-camera run proves that.

## Repository setup status

The Linux Flutter scaffold is in progress for issue #2. Use the [connection development guide](docs/development/connection.md) for SDK setup, verified test/analyze commands and desktop validation results. [Project context](docs/context.md) records approved integrations; [environment](docs/development/environment.md) separates measured prerequisites from untested behavior. Follow the [standard Flutter BDD approach](docs/development/testing.md#use-standard-flutter-tooling-for-bdd), including visual/hardware checks. Real-camera tests will be performed together with the owner after scoped approval. The [handoff](docs/development/validation-handoff.md) preserves prior evidence; issue approval alone does not authorize hardware operations.

Keep local proprietary research inputs/decompiler output in ignored `research-artifacts/`. Never commit credentials or personal media. Community code needs a license/provenance check before reuse. The project license itself is still undecided.

The initial documentation-only scaffold is the owner's explicit exception to the issue requirement. It is not permission to start the first app slice.
