# Existing Flutter Android implementation

Research date: 2026-11-16. Source inspection only: no build, APK execution, security audit or camera test was performed.

## Identity and status

Repository: https://github.com/xiaobaiwud12/yi-m1-controller-app

Reviewed commit: `dc3a659dcee01d075ddc7bb3c4d3dede7986653e`. GitHub reports repository creation on 2026-09-16. This is recent community work, not the original manufacturer application.

The README at this commit describes BLE pairing, joining camera Wi-Fi, HTTP controls, UDP JPEG live view, browsing camera-card media and copying selected files to an Android phone. It identifies the camera as YI M1 / `C59Y1`.

**Important qualification:** the maintainer says an original delivered version worked, but their camera is now unusable and the **current source has not been verified with a real camera**. Offline/emulator checks are explicitly not proof of hardware behavior. We have not independently verified any hardware claims.

`app/pubspec.yaml` declares source version `0.2.4+6`. GitHub Releases lists `v0.2.4`, published 2026-10-18, with an approximately 19.7 MB APK. The README specifies Android 7.0/API 24+ and arm64-v8a release APKs. These are upstream requirements, not choices for this project.

## Evidence relevant to photo browsing and downloading

| Capability | Evidence in reviewed source | Qualification |
| --- | --- | --- |
| List camera media | `app/lib/transport/album.dart`, `listPage()`, sends `GetFileList` with `range_start` and `range_end`, parses a JSON `data` list. | Its pagination assumptions must be checked on the user's firmware. Other M1 clients use different ranges. |
| Request a preview or original | `FileResolution` has `Original`, `MidThumb`, `Thumbnail`. The download method sends `GetFile` with `path` and **`resulotion`**. | The misspelling is part of the reported camera protocol. |
| Receive photo bytes | The code creates an HTTP URL with a JSON `data` query and reads a raw binary response. | Source evidence for an implementation; not a successful download in our environment. |
| RAW/JPEG handling | The code groups paired files and comments report firmware-specific RAW thumbnail failures (`204`/`404`). | Do not generalize these observed responses to all firmware or assume RAW preview is available. |
| Save to phone | Android `MediaStore` code and an asset sink target `DCIM/YI M1/`. | This does not provide an iOS Photos implementation. |
| Avoid overlapping requests | Album operations use a shared request gate. The README says camera HTTP work is serial. | Useful design evidence, but throughput and safe concurrency need device measurements. |

## Platform coverage is Android, not Android + iOS + web

The tree at this commit has `app/android/`, but no `app/ios/` or `app/web/` platform project.

`app/lib/platform/wifi_joiner.dart` uses an Android method channel and returns an unsupported result when `!Platform.isAndroid`. Media storage also has Android/Kotlin code. Transport and album files import `dart:io`.

Therefore, although this is Flutter, it is **not an already completed cross-platform solution**. Porting would need iOS Wi-Fi, permissions and photo/file storage work, real BLE tests, project setup and signing. A web build requires a separate transport feasibility decision; replacing Android build files alone will not make the client browser-compatible. See [platform feasibility](platform-feasibility.md).

## License and provenance

The actual `LICENSE` file declares **Apache-2.0**; GitHub's API categorizes it as `NOASSERTION`/Other, so the API label alone is misleading. `NOTICE` describes third-party components and MIT-derived protocol material. Read both files and the resolved dependency licenses before copying or distributing a derivative.

This inspection establishes what the license and notice files say. It does not certify that every included component has the claimed provenance or that a prebuilt APK exactly matches the source. No vendor APK/decompiled source was imported into this repository.

## Reliability cautions

The protocol notes are detailed but not internally consistent in every section. For example, their later unresolved-items table still calls the time payload uncertain after an earlier section claims confirmation from the original APK. BLE write-mode notes describe platform-specific uncertainty. Their categorical claims about camera security, lack of RTC hardware and firmware behavior should not be adopted as independently proven facts.

Treat source code, upstream measurements and hypotheses as separate evidence. Start with a narrow, read-only camera test rather than enabling all the remote-control, deletion or firmware commands included in community tooling.

## Implication for this project

This is a strong candidate to **evaluate as a reference or starting point before writing a new app**. It already addresses much of the requested Android gallery/download workflow. We have not chosen to fork it or recommended installing its APK. That decision should follow a source/dependency review and a controlled test on the user's camera.

## Pinned sources

- [README](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/README.md)
- [License](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/LICENSE)
- [Third-party notices](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/NOTICE)
- [Package manifest](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/pubspec.yaml)
- [Protocol notes, Chinese](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/docs/PROTOCOL.md)
- [Album transport](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/lib/transport/album.dart)
- [HTTP transport](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/lib/transport/http_transport.dart)
- [Android Wi-Fi integration](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/lib/platform/wifi_joiner.dart)
- [Android storage integration](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/lib/platform/asset_sink.dart)
- [Tree at reviewed commit](https://github.com/xiaobaiwud12/yi-m1-controller-app/tree/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app)
- [Published releases](https://github.com/xiaobaiwud12/yi-m1-controller-app/releases)

API checks: https://api.github.com/repos/xiaobaiwud12/yi-m1-controller-app and https://api.github.com/repos/xiaobaiwud12/yi-m1-controller-app/releases?per_page=10 . All source links were retrieved on the research date.
