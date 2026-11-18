# YI M1 Reborn

A planned replacement companion app for the **Xiaoyi / YI M1 mirrorless camera**: browse camera photos, download selected originals, see live view and take a photo remotely.

**Status:** Linux connection work in progress for [issue #2](https://github.com/cltec/yi-m1-reborn/issues/2). Joint camera tests verified saved pairing and BLE-session reuse after an app restart. Wi-Fi/reachability is implemented against simulated boundaries, with owner decisions and real-network validation still pending.

## Agreed direction

- **Camera:** owner-confirmed firmware **3.2-int**.
- **Platforms:** Linux desktop first: Pop!_OS 22.04 LTS (Ubuntu 22.04-based); Android and iOS later.
- **Gallery:** automatically connect to the remembered camera, show thumbnails/previews, download selected JPEG and RAW originals.
- **Live:** display the live feed and trigger a photo saved on the camera only.
- **Architecture:** Ports and Adapters.
- **Delivery:** vertical slices with approved issue specifications, BDD acceptance scenarios, incremental TDD, and one issue-linked branch/PR per slice.

Flutter 3.44.4 with bundled Dart 3.12.2 is pinned for the first slice. BDD uses standard Flutter test tools without a separate Gherkin runner. Linux screenshots will use ImageMagick `import` for app-window-only captures. Sanitized screenshot evidence will be stored in the repository and embedded in the PR. Remaining integrations and project license remain open. Web is not a current delivery target. See [context](docs/context.md) for exact scope and unresolved decisions.

Delivery is split into camera connection (#2), then photo filename listing (#3). See [connection development](docs/development/connection.md) for verified checks, the resolved desktop build blocker and the proposed joint camera test. Saved BLE-session reuse passed a joint restart test; complete Wi-Fi/HTTP connection and password-persistence checks remain unverified. Issue #2 is open; #3 is not ready to start.

## Start here

| Reader need | Entry point |
| --- | --- |
| AI-agent onboarding | [AGENTS.md](AGENTS.md) |
| Current scope and glossary | [Project context](docs/context.md) |
| Find documentation | [Documentation index](docs/README.md) |
| Start contributing | [CONTRIBUTING.md](CONTRIBUTING.md) |
| Understand the design and rationale | [Architecture](docs/architecture/README.md) and [ADRs](docs/decisions/README.md) |
| Follow the development process | [Workflow](docs/development/workflow.md) and [testing strategy](docs/development/testing.md) |
| Inspect camera evidence | [Research summary](docs/research/README.md) |

Run `flutter test` and `flutter analyze` from the repository root; see the [connection guide](docs/development/connection.md) for setup and limits. The Linux integration test passes with simulated discovery after the owner installed the missing C++ development package. Current code is not a completed connection feature. Hardware-dependent slices remain **implemented but awaiting hardware validation** until successfully tested on the owner's camera on the agreed target desktop (Pop!_OS 22.04 for issue #1).

## Camera research

The manufacturer and original app confirm **BLE pairing/setup → Wi-Fi photo access**. Public M1-specific clients and an archived original Android APK have been inspected. Research includes [hardware/manuals](docs/research/camera-hardware.md), [app archives](docs/research/app-archives.md), [direct static analysis](docs/research/original-app-analysis.md), [protocol prior art](docs/research/protocol-prior-art.md), [Flutter prior art](docs/research/flutter-prior-art.md) and [platform feasibility](docs/research/platform-feasibility.md).

The initial research is dated 2026-11-16 and is preserved with source links and confidence limits. Community hardware claims are not this project's test results.

Downloaded proprietary binaries, manuals, decompiled output and research tools stay locally in gitignored `research-artifacts/`. They are not distributable project source. Do not install archived apps or flash firmware merely because the research links them.

Repository: [cltec/yi-m1-reborn](https://github.com/cltec/yi-m1-reborn).
