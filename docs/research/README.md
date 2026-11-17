# YI M1 research summary

> Historical research snapshot. The owner subsequently confirmed **3.2-int**, Pop!_OS 22.04 LTS first (Ubuntu 22.04-based), then Android and iOS. See [current project context](../context.md) and [documentation index](../README.md). Unanswered questions below reflect the initial investigation, not a request to re-ask already answered questions.

**Research date: 2026-11-16. Status: initial web research and static app analysis complete; device validation not performed.**

## Answer to the original question

A replacement app for browsing and downloading YI M1 photos looks **technically feasible on native Android and iPhone**, subject to testing the actual camera firmware and phones. We are not starting from an unknown protocol: M1-specific reverse engineering and independent clients already exist.

**Important correction to the connection model:** Bluetooth Low Energy establishes pairing and enables the camera's Wi-Fi. Stored photographs are accessed over **Wi-Fi**, not a demonstrated Bluetooth-only photo channel. The manufacturer explicitly describes this sequence, and it matches both the archived original app and community code. [Hardware](camera-hardware.md), [original app analysis](original-app-analysis.md), [protocol](protocol-prior-art.md).

Flutter remains a credible option for a shared native application. A **web version with identical direct-camera features is a separate, unresolved feasibility question**, particularly on iPhone/Safari. Flutter does not remove browser Bluetooth, socket, CORS or local-network restrictions. [Platform feasibility](platform-feasibility.md).

No app specification, framework choice, fork, plugin choice, minimum OS requirement or firmware change has been agreed.

## Strongest findings

| Finding | Evidence | Confidence / limit |
| --- | --- | --- |
| Exact original app identified | Vendor M1 page links Android `com.xiaoyi.mirrorlesscamera` and Apple ID `1111129550`. | Primary-source identity; not a promise of present installability. |
| Manufacturer material survives | Official product pages, regional download listings and English manual located. | Current page content verified; firmware availability/version history is not the same as compatibility. |
| Original Android APK obtained | Archive candidate `3.1.6_20190517`, version code 51, 23,076,298 bytes; SHA-256 recorded. | Third-party archive, not a direct vendor binary. Certificate metadata matches archive; not a malware audit. |
| Original APK statically decompiled | jadx 1.5.6 completed; BLE, gallery, HTTP and time helper code inspected. | Reconstructed code only; no execution or camera connection. |
| Gallery wire format recovered | `GetFileList`; `GetFile` with `Thumbnail`, `MidThumb`, `Original`; exact spelling **`resulotion`**. | Corroborated by original app and public clients; firmware-specific behavior still needs tests. |
| Native local transfer has prior art | Standalone Python client, Swift iOS project and Flutter Android app. | Author-reported hardware results, with explicit untested-port/current-source caveats. |
| Vendor cloud may be avoidable for the core workflow | Standalone community implementations use local BLE/HTTP/UDP without a cloud-login API. | Strong source evidence, not end-to-end verification on this camera or proof all original-app UI is offline. |
| Original Android APK has modern-phone constraints | Native libraries only under `armeabi-v7a`, target SDK 26. | Static package facts; no install attempt. A rebuild/replacement is distinct from merely finding an old APK. |
| Apple listing still responds | US App Store page and lookup API returned the original app, last version 3.1.1 (2019). | Listing availability does not establish successful installation or operation on modern iOS. |

## Protocol at a glance

The following values are recovered facts/reference-client behavior, **not constants introduced into an application in this repository**:

| Area | Finding |
| --- | --- |
| BLE service | `41106dd9-25ad-477b-a884-5038b6de4649` |
| Pairing/session | Camera-screen approval, decimal reference ID, returned token, CRC32-based session payload |
| Wi-Fi credentials | Read from BLE; Wi-Fi enabled through BLE |
| Camera HTTP base | `http://192.168.0.10/?data=<JSON>` |
| List photos | `GetFileList`, with range parameters and `filetype: "all"` in original client |
| Original gallery page policy | One-based, 60 entries/page; community clients also use other ranges |
| Preview/download | `GetFile`, camera-returned `path`, **`resulotion`**; original gallery also includes `date` |
| Live view, separate from stored photos | UDP 54321; community clients reconstruct JPEG frames |

Do not reuse YI **action-camera** TCP 7878 / `msg_id` / RTSP assumptions or YI **Home** protocols. Same brand does not imply the same camera API.

One useful correction came from following the original app's call flow: **camera time sync adds the phone's timezone/DST offset before sending decimal seconds**. It is not simply UTC epoch seconds as some community notes suggest. Time sync is not required as an automatic side effect of initial gallery testing. [Direct analysis](original-app-analysis.md#important-correction-camera-time-synchronization).

## Existing projects worth evaluating

| Project | What it offers | Reuse caution |
| --- | --- | --- |
| [bullbin/xiaoyi_m1_re_liveview](https://github.com/bullbin/xiaoyi_m1_re_liveview) | Small M1 BLE/HTTP/UDP proof of concept; reported 3.2-int camera tests | MIT; useful protocol foundation, not a finished mobile gallery |
| [echeetah/yi-m1-monitor](https://github.com/echeetah/yi-m1-monitor) | Swift iOS and Python/macOS apps, gallery/control and detailed notes | MIT; device coverage differs by component and some notes have later corrections |
| [xiaobaiwud12/yi-m1-controller-app](https://github.com/xiaobaiwud12/yi-m1-controller-app) | Flutter Android controller with media selection and downloads | Apache-2.0 + notices; Android-specific Wi-Fi/storage; current source explicitly not hardware-verified |
| [protyposis/yi-mirrorless-firmware-tools](https://github.com/protyposis/yi-mirrorless-firmware-tools) | Firmware structure and early M1 HTTP research | GPL-3.0 text; analysis reference, not a reason to modify firmware |

Pinned revisions, additional projects, license evidence and conflicting claims are in [protocol prior art](protocol-prior-art.md). The [Flutter review](flutter-prior-art.md) distinguishes source evidence from tested behavior. No existing APK is recommended for installation solely on the basis of this research.

## Collected knowledge

1. [Camera hardware, specifications, manual and vendor sources](camera-hardware.md).
2. [Original Android/iOS app identities, historical releases, archives and provenance](app-archives.md).
3. [Direct static analysis of original app protocol behavior](original-app-analysis.md).
4. [BLE/HTTP/UDP protocol reference and reverse-engineering prior art](protocol-prior-art.md).
5. [Existing Flutter app and reuse considerations](flutter-prior-art.md).
6. [Android/iOS/web constraints](platform-feasibility.md).
7. [Proposed future device checks](device-validation.md).

Committed evidence metadata is under [evidence/](evidence/). Downloaded binaries/manuals, raw vendor pages, decompiler tools and generated source stay in gitignored `research-artifacts/`; they are local research material, not redistributable project source. Hashes and URLs allow provenance checks without committing proprietary app code.

## Remaining uncertainties

- The user's camera firmware/region and the intended phone/OS versions.
- BLE write-mode differences, pairing persistence, and effects of replacing the original pairing.
- File-list ranges and large-card behavior on the actual firmware.
- JPEG/DNG/RAW+JPEG preview availability, original-file integrity and transfer reliability.
- Camera mode requirements and whether HTTP operations must be serialized.
- Native platform permissions, joining a no-Internet camera network, and saving originals to the user's chosen destination.
- Direct browser access: no universal Android+iPhone web workflow has been demonstrated.

There is **no acquisition blocker for initial Android static analysis**: an app candidate was obtained and decompiled. An original iOS IPA was not obtained. No firmware modifications are needed to justify the current feasibility assessment.

## Next discussion

Before product specifications, the most useful inputs are the camera's **firmware version/region** and your **phone models/OS versions**. No serial number or personal photos are needed. If an old phone still has the app, keep it intact for possible comparison.

A later, explicitly approved validation can test pairing, a small file list and one original JPEG download against the SD-card file. Only then should we choose whether to adapt an existing client or build a smaller shared implementation and discuss the full application requirements.

## Assumptions and changes

- Assumed the device is the **Xiaoyi / YI M1 Micro Four Thirds mirrorless camera**, not a YI action/home camera. Manufacturer and app identity sources consistently match that model.
- Assumed initial work should gather knowledge, not implement or deploy an app, as requested.
- Community test claims remain attributed, not silently promoted to our own verified results.
- Added research documentation and `.gitignore` coverage for local third-party artifacts. **No app constants, camera settings or firmware were changed.** No camera was contacted.
