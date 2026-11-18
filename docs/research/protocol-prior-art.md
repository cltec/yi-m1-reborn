# YI M1 protocol and reverse-engineering prior art

## Scope and evidence

**Retrieved: 2026-11-16.** This is a source-based reference for the **Xiaoyi / YI M1 (`C59Y1`) mirrorless camera**, not the YI action camera or YI Home range. For this protocol-prior-art review, no camera, firmware image, APK, BLE capture, or Wi-Fi capture was tested. Separate project research downloaded and decompiled the original APK without executing it; see [app archives](app-archives.md) and [original app analysis](original-app-analysis.md). “Author tested” below describes a source author's claim, not our verification. Source code was inspected through public GitHub API and raw-file HTTPS requests; no MCP was used.

The strongest starting point is **bullbin's M1-specific BLE → Wi-Fi HTTP → UDP implementation**, explicitly reported working with **3.2-int**. The protocol is not an undiscovered action-camera API. Complete newer app implementations also exist, so adapting prior art deserves evaluation before writing a replacement from scratch.

### Repository inventory

| Project | Exact revision inspected | Evidence and scope | License checked |
|---|---|---|---|
| [bullbin/xiaoyi_m1_re_liveview](https://github.com/bullbin/xiaoyi_m1_re_liveview) | `52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca` | Python PoC; README names official Android app **YI Mirrorless 3.1.6**, BLE/Wi-Fi packet captures, and tested body firmware **3.2int**. Supports final BLE protocol 1 and WLAN protocol for firmware ≥2.2, but does not claim earlier firmware works. [B-README](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/README.md) | **MIT**, copyright 2024 bullbin. [B-LICENSE](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/LICENSE) |
| [protyposis/yi-mirrorless-firmware-tools](https://github.com/protyposis/yi-mirrorless-firmware-tools) | `b90b96c124a3b076fa0283404e6595a4a40d20d0` | Node.js firmware unpack/repack/region tool; early M1 HTTP-server observations. Repository created 2017-10-25 per GitHub metadata. [P-README](https://github.com/protyposis/yi-mirrorless-firmware-tools/blob/b90b96c124a3b076fa0283404e6595a4a40d20d0/README.md) | **GPL-3.0 license text** in `LICENSE.md`. [P-LICENSE](https://github.com/protyposis/yi-mirrorless-firmware-tools/blob/b90b96c124a3b076fa0283404e6595a4a40d20d0/LICENSE.md) |
| [echeetah/yi-m1-monitor](https://github.com/echeetah/yi-m1-monitor) | `e1fbaeba7f2be2320794e61523d0cff799d739e5` | Python/PySide6 macOS and Swift/SwiftUI iOS apps; reported live tests on one **3.2-int** camera; detailed protocol and firmware notes. [E-README](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/README.md) | **MIT**, copyright 2026 max; does not license OEM firmware/app. [E-LICENSE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/LICENSE) |
| [xiaobaiwud12/yi-m1-controller-app](https://github.com/xiaobaiwud12/yi-m1-controller-app) | `dc3a659dcee01d075ddc7bb3c4d3dede7986653e` | Flutter Android controller, gallery and file transfer. Protocol notes identify hardware as **`1,3.1-cn ,M1CN,0.0`**. README states the original delivered app worked, but **current source has not been tested on a real camera because that camera is unusable**. [F-README](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/README.md) [F-PROTOCOL](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/docs/PROTOCOL.md) | **Apache-2.0** application; third-party attribution in `NOTICE`, including MIT-derived protocol material. [F-LICENSE](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/LICENSE) [F-NOTICE](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/NOTICE) |
| [zeroa234/XIAOYI_M1](https://github.com/zeroa234/XIAOYI_M1) | `d4594656b2654877f0e84323adaaf2698cbb0cc7` | Chinese-language firmware research, chiefly **3.2-cn**, with 3.1-cn comparison; ARM maps, HTTP/UDP live-view tools, codec/boot research. **Reports a failed experimental flash and unbootable camera.** [Z-README](https://github.com/zeroa234/XIAOYI_M1/blob/d4594656b2654877f0e84323adaaf2698cbb0cc7/README.md) | No root license file found; README explicitly says no unified open-source license designated. Do not treat public code as permissively licensed. |
| [feletoch/Yi-M1-Android-app-patch](https://github.com/feletoch/Yi-M1-Android-app-patch) | see [A-README](https://github.com/feletoch/Yi-M1-Android-app-patch/blob/9e084ed549f75ae4d7ec96e304ad57913e1f5667/README.md) pinned URL | Patch/rebuild of OEM Android **3.1.6**, replacing 32-bit native image/live-view dependencies with Java; author claims real-camera Android 16 pairing, UDP, gallery, DNG transfer, shutter and offline guide tests. Not an independent clean-room app. | No root license file found. README acknowledges patched APK contains original application code; rights to that code are not established by public availability. |

**2026 provenance:** GitHub metadata reports echeetah created **2026-07-23**, Flutter app **2026-09-16**, and zeroa234 **2026-10-28**. Those are repository creation dates, not independent proof of experiments. Echeetah's notes claim experiments dated July 2–24, including before repository creation. These are current public sources at retrieval time, not historical evidence available in 2017 or 2024. Several contain corrected or stale claims, identified below.

For the Flutter app's implementation/reuse review, see [Flutter prior art](flutter-prior-art.md).

## BLE discovery and GATT

The following literal identifiers are in bullbin's `const_ble_uuid.py` [B-UUID](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_ble/const_ble_uuid.py). The suffix for abbreviated entries is **`-25ad-477b-a884-5038b6de4649`**.

| UUID | Source name / use | Evidence limit |
|---|---|---|
| `41106dd9-25ad-477b-a884-5038b6de4649` | M1 service; discovery filter | Bullbin scans by this service, sorts RSSI, and excludes RSSI below −50. The −50 cutoff is a PoC policy, **not a camera requirement**. |
| `41106da2-…` | Firmware info, read | Parsed as `protocol,body,variant[,lens]`; trailing NUL padding removed. |
| `41106da0-…` | Pairing initiation, write | Triggers physical confirmation on camera. |
| `41106da7-…` | Pairing-result notification | Non-empty ASCII token = accepted; empty = denied. |
| `41106da4-…` | Session initiation, write | Protocol/key/CRC32 payload, below. |
| `41106da6-…` | Wi-Fi AP credentials, read | ASCII `SSID,password`, protected until session initiation. |
| `41106da5-…` | Wi-Fi switch, write | PoC sends literal ASCII `ON`. |
| `41106da9-…` | Pairing forget | Constant exists; not exercised by bullbin PoC. |
| `41106dac-…` | Time sync | Constant exists; not implemented in bullbin PoC. Flutter notes simplify this as ASCII Unix epoch seconds. **Our separate original-APK decompilation finds a timezone adjustment:** `TimeUtil.a()/1000`, where the helper adds current zone+DST offsets in milliseconds before division; this represents local-wall-clock-shifted seconds, not plain UTC epoch seconds. See [original app analysis](original-app-analysis.md); confirm against target camera and timezone. [F-PROTOCOL](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/docs/PROTOCOL.md) |
| `41106dad-…`, `41106dae-…`, `41106daf-…` | Resume/state and optional notifications | Bullbin subscribes `af` and `ae`, writes `3` to `ad` when `af` exists. |
| `41106da1-…` | `RESPONSE_TOKEN` constant | **Do not require it:** Flutter's 3.1-cn hardware report says absent and unused/tolerated by OEM app. |

Standard Device Name `2a00`, Appearance `2a01`, Model Number `2a24`, and Manufacturer `2a29` are also listed [B-UUID](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_ble/const_ble_uuid.py). Their presence is not universal: echeetah reports Device Name absent on its test camera, manufacturer **Xacti**, model **ASDK00** [E-LIVE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/live-testing-findings.md). Its Swift port treats informational reads as optional [E-BLE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/BLEPairing.swift). This is useful M1 identification evidence, not proof all units report those strings.

### Handshake reproduced from source, not tested here

Bullbin's actual `ble_keyhack.py` sequence [B-BLE](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_ble/ble_keyhack.py):

1. Connect and read firmware info from `da2`.
2. Subscribe to `da7`; generate decimal `key` in **0…99998**; write ASCII **`<protocol>,<key>,android`** to `da0` with response requested.
3. Wait for user to accept on camera. Retain the returned ASCII token.
4. Calculate **unsigned CRC32 of ASCII `"1" + key + token`** using `zlib.crc32`. Write decimal ASCII **`<protocol>,<key>,<checksum>`** to `da4`. The checksum input starts with literal `1`, not a dynamically substituted protocol string in this implementation.
5. If `af` exists, subscribe `af` and `ae`, then write ASCII **`3`** to `ad`.
6. Read `da6`; split into `SSID,password`. Then write ASCII **`ON`** to `da5`.
7. End BLE connection and join camera Wi-Fi using the returned credentials.

Bullbin says only **one pairing key** is retained; re-pairing replaces the official app's pairing. Its PoC always re-pairs; reusing saved key/token is a TODO, not demonstrated persistence in that code. Its README reports a randomized eight-digit Wi-Fi password each session [B-README](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/README.md). CRC32 is not cryptographic authentication; do not market this as secure pairing. The camera-screen confirmation is material user authorization.

**Compatibility warning:** Flutter's 3.1-cn notes report with-response writes producing ATT application error `0x80`, unlike bullbin's with-response implementation. They also note Android rejects unsupported write-without-response properties before sending. These are source-reported firmware/platform differences and unresolved recovery cases, not justification to hard-code either method for all units [F-PROTOCOL](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/docs/PROTOCOL.md). Echeetah's Swift `BLEPairing.swift` itself says that port's handshake was not yet exercised on-device, despite broader README claims. Treat platform-specific test coverage separately from protocol evidence [E-BLE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/BLEPairing.swift).

## Wi-Fi control and photo transfer

### Control endpoint

M1-specific evidence from both 2017 firmware-tools notes and bullbin source is:

- Camera is a Wi-Fi AP at **`192.168.0.10`**.
- HTTP root endpoint: **`GET http://192.168.0.10/?data=<JSON>`**.
- Example logical JSON: **`{"command":"GetCameraStatus"}`**.
- Author reports say only the first Wi-Fi client receives an address; disconnect the official phone app before connecting a replacement client. This is not evidence that a second controlled connection can never exist under any firmware.
- `RCStartRemoteCtl` enters remote control, `RCStopRemoteCtl` exits; bullbin `debug_html.py` directly constructs and sends the start request. [P-README](https://github.com/protyposis/yi-mirrorless-firmware-tools/blob/b90b96c124a3b076fa0283404e6595a4a40d20d0/README.md) [B-README](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/README.md) [B-HTTP](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/debug_html.py)

There is no action-camera `msg_id`/TCP session token in these M1 HTTP examples. Their HTTP payloads carry no cloud login, API key, or pairing token. This supports **local offline control**, not a security audit proving no possible authentication in every firmware.

### Gallery and transfer wire shapes

Bullbin's builders expose the field names and download literals below; the illustrated **0…9999** listing range follows echeetah's builder, not bullbin's defaults [B-CMD](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_http/command_http.py) [B-ENUM](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_http/const_http_enum_extra.py):

```json
{"command":"GetFileList","range_start":"0","range_end":"9999","filetype":"all"}
{"command":"GetFile","path":"<path returned by camera>","resulotion":"Thumbnail"}
{"command":"GetFile","path":"<path returned by camera>","resulotion":"MidThumb"}
{"command":"GetFile","path":"<path returned by camera>","resulotion":"Original"}
```

**`resulotion` is the protocol spelling. Do not correct it to `resolution`.** `Thumbnail`, `MidThumb`, and `Original` are case-sensitive source literals. `GetFile` returns binary media bytes, not JSON. Echeetah implements binary-preserving downloads and disk streaming, and serializes downloads/control requests [E-HTTP](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/HTTPClient.swift). Its file parser documents an author-observed response [E-FILE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/CameraFile.swift):

```json
{"code":200,"data":[{"path":"...","date":"<unix timestamp string>","filetype":"picture","protectStatus":false}]}
```

Other documented `filetype` values are `rawJpeg`, `raw`, and `video`. Read exact camera-returned paths rather than constructing paths from filenames.

**Pagination is not settled across sources.** The example above follows echeetah's **3.2-int** builder, which says range **0…9999** works and **0…0** returns `{"code":1502,"data":"get filelist err"}` [E-CMD](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/Commands.swift). Bullbin's constructor defaults to **0…0**, so its defaults are not a good successful-listing example. Flutter's **3.1-cn** notes say **one-based, 60 entries/page**, and require `range_start`/`range_end` [F-PROTOCOL](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/docs/PROTOCOL.md). Separate direct decompilation of the original app corroborates **one-based, 60-entry default pagination** in `CameraAlbumManager` (`common/e.java`) and a **`date` field alongside `path` and `resulotion`** in original gallery download URLs; see [original app analysis](original-app-analysis.md). This establishes original-client behavior, not that firmware rejects all other ranges or requires `date` in every request. Gallery pagination, optional fields and large-card behavior still need target-device tests.

Echeetah's HTTP implementation reports success as JSON **`code:200`**, not `code:0`; HTTP 200 alone is insufficient. Required-parameter failures can appear as HTTP **404**, so 404 does not establish an unsupported command. Its URL builder preserves literal `/` in paths and removes JSON `\/` escaping after a reported on-device file/download bug; other implementations percent-encode JSON. Exact URL encoding therefore also needs target-client testing [E-HTTP](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/HTTPClient.swift).

### Additional controls and firmware safety

Bullbin exposes ISO, aperture, shutter, focus, EV, WB, image aspect/quality/format, drive mode, focus trigger and photo shutter [B-CMD](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_http/command_http.py). Echeetah documents author-tested `VideoRecordingStart`/`VideoRecordingStop`, then `RCVideoFormatSet` with **`Resolution`**, including recorded-file/`ffprobe` evidence for FHD 23.976 versus 29.97 fps [E-VIDEO](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/rcvideoformatset-solved.md). Its notes distinguish a command being accepted from a setting applying: `4K_24` and `4K_30_LOW` were accepted but reverted to `4K_30` at record start. These newer capabilities are not needed merely to browse/download images.

**Stale source warning:** echeetah's `Commands.swift` still lists `RCVideoFormatSet` and related setters under `DeadCommands`; the later correction explicitly supersedes that conclusion [E-CMD](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/Commands.swift) [E-VIDEO](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/rcvideoformatset-solved.md). Old bare-command 404 tests are not a reliable feature inventory.

`UpdateFW`, `UpdateLenFW`, deletion and upload commands appear in source. Their presence is **not permission or a recommendation to invoke them**. Photo browsing/download does not require firmware modification.

## UDP live view

Bullbin implements a UDP receiver bound on the **client** at **54321** [B-UDP](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/udp_bitmap_decoder.py). After `RCStartRemoteCtl`, each datagram starts with:

| Offset | Encoding | Meaning in decoder |
|---|---|---|
| 0…3 | uint32, big-endian | Frame index |
| 4…7 | uint32, big-endian | Number of packets for this frame |
| 8…11 | uint32, big-endian | Packet index, zero-based in implementation |
| 12…end | Bytes | Fragment payload |

Concatenate fragment payloads for a complete frame. The first **2048 bytes** are metadata; bytes after 2048 are the JPEG. README reports **800×600** JPEG live view [B-README](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/README.md). The PoC discards a frame after non-sequential packets; that is its implementation policy, not proof UDP delivery is ordered. The Android-app patch independently implements the same header, metadata/JPEG split, and claims a maximum frame buffer `0x19000` [A-README](https://github.com/feletoch/Yi-M1-Android-app-patch/blob/9e084ed549f75ae4d7ec96e304ad57913e1f5667/README.md). Its README says older firmware follows a different large-single-packet path. Do not use one tested framing variant as proof of all-version support.

No inspected M1 implementation needs RTSP for this live view. Identical UDP port numbers used by other YI products do not establish identical frame protocols.

## Firmware and hardware lineage

Protyposis documents four update-image sections: main code (two 4096-byte blocks then three LZSS compressed streams), `ND1` resources, `IPL` bootloader, and `PTBL` partition table. Headers are 256-byte text records containing lengths, region/model and byte-sum checksums. Example **2.9.1-int** header: `C59Y1 VER=M1INT DVR=Ver1.37`. Strings include **ARM926**, **EV9x**, Broadcom/Murata radio identifiers and `C:/XC_ODM/sdk/...` [P-README](https://github.com/protyposis/yi-mirrorless-firmware-tools/blob/b90b96c124a3b076fa0283404e6595a4a40d20d0/README.md). Echeetah's reported Xacti GATT manufacturer supports that OEM lead [E-LIVE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/live-testing-findings.md). Neither is evidence of an Ambarella action-camera firmware target.

Protyposis's unpacker is useful prior art for offline analysis but explicitly warns decompression/compression is not fully correct and **not to flash repacked files**. Its historical official firmware link, <https://www.yitechnology.com/yi-m1-mirrorless-camera-firmware>, returned **HTTP 404 on 2026-11-16**. This specific historical-page retrieval did not obtain or authenticate a firmware download; the 404 does **not** establish that official firmware is unavailable. Separate project research found live official listings through `api.yitechnology.com` and `www.xiaoyi.com/weidan_download.html` (see [camera hardware and official sources](camera-hardware.md)). The newer zeroa234 archive reports an experimental **3.2-d1 flash causing a black screen/unbootable unit**, withdrawn packages, and no verified software-only recovery [Z-README](https://github.com/zeroa234/XIAOYI_M1/blob/d4594656b2654877f0e84323adaaf2698cbb0cc7/README.md). That safety evidence outweighs optimistic assumptions that a matching checksum or offline round trip makes flashing safe.

Firmware-format similarities with Fujifilm/Xacti cameras are research leads, **not proof their PTP, remote-control protocol, or firmware images are interchangeable**.

## PTP/IP and USB: what is and is not known

No inspected M1-specific implementation uses **PTP/IP**. No M1 PTP/IP listener, port, operation table, discovery message, or working tethering client was verified in this research. GitHub repository search for `"YI M1" PTP` returned no repositories on retrieval; that is a limited search result, not proof of absence.

Echeetah's USB note reports a real macOS descriptor inspection with **class 8**, **subclass 6**, **protocol `0x50`**, and normal mass-storage mounting. It explicitly retracts an earlier inference from the firmware string `MTPClassDriver` that an accessible PTP/MTP responder must exist [E-PTP](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/ptp-mtp-attack-surface.md). **USB mass-storage observation does not prove PTP/IP is absent over Wi-Fi.** Conversely, a firmware string or a related Fujifilm PTP implementation is not proof M1 PTP/IP exists. Hidden USB modes, alternate firmware and network PTP remain unknown.

## Explicit separation: YI action-camera / Ambarella protocols

The following is **comparison-only, not an M1 implementation plan**:

| Family/source | Observed source interface | Relevance to M1 |
|---|---|---|
| [dr1s/yiac](https://github.com/dr1s/yiac), explicitly Xiaomi YI **Action Camera** | Defaults **192.168.42.1:7878**, TCP socket JSON `msg_id`, `token`; token request **257**, RTSP enable **259**, stream `rtsp://<ip>/live` | Does **not** match the inspected M1 HTTP commands, BLE credentials or UDP frame transport. [ACTION-CODE](https://github.com/dr1s/yiac/blob/9a8709687d6ac30e0270ebad66baaa5bc3f81c2c/yiac/api.py) [ACTION-README](https://github.com/dr1s/yiac/blob/9a8709687d6ac30e0270ebad66baaa5bc3f81c2c/README.md) |
| [Informatic/ambarpc](https://github.com/Informatic/ambarpc) | README calls it an **Ambarella API (`network_message_daemon`) client**, mostly tested on Xiaoyi/Xiaomi YI camera | Same brand is not evidence M1 runs this daemon. [AMBA-README](https://github.com/Informatic/ambarpc/blob/7ec9210c38f4510a4de053e473e93afb26a20380/README.md) |

No evidence found supports assuming M1 uses TCP 7878, action-camera `msg_id:257`, default action-camera credentials, an Ambarella `autoexec.ash` path, or RTSP `/live`. Those may be correct for other YI hardware; they are not justified M1 constants.

## Offline/cloud boundary and remaining unknowns

- **Supported by inspected source:** M1 BLE discovery, user-confirmed pairing, Wi-Fi enable, HTTP control, file list/download and UDP live view can be implemented without YI cloud login. Bullbin's PoC is standalone local code, not a wrapper around a cloud SDK [B-BLE](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_ble/ble_keyhack.py) [B-HTTP](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/debug_html.py) [B-UDP](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/udp_bitmap_decoder.py).
- **Not established:** that every firmware/version works offline in every state, all phone OS permissions/routing work, or saved pairings reliably resume without user confirmation.
- The patched OEM app says cloud login/store/notifications/sharing servers no longer work and moves Master Guide templates offline [A-README](https://github.com/feletoch/Yi-M1-Android-app-patch/blob/9e084ed549f75ae4d7ec96e304ad57913e1f5667/README.md). That does not establish a cloud dependency for ordinary camera-file access. Legal and supply-chain review of patched OEM APKs remains separate.
- **Unavailable source:** <https://github.com/Qgrade/Yi-M1-mirrorless>, credited by bullbin, returned GitHub API **404** on 2026-11-16. “Deleted” is echeetah's description; the response alone cannot distinguish deletion, privacy or unavailability. Do not cite its uninspected contents as verified commands.
- Required target-device checks: body/region/protocol identification, actual advertised GATT and write properties, pairing persistence and replacement, Wi-Fi credentials/routes, file-list pagination, JPEG/DNG/RAW+JPEG paths, thumbnail availability, original-byte integrity, HTTP serialization and URL escaping, and recovery after disconnect. None were performed here.
- **Assumptions made:** source authors' hardware claims are useful but unverified reports; exact target firmware is unknown; current public default-branch revisions are the versions worth comparing. **No application constants or camera settings were changed.**

## Pinned sources

All sources below were retrieved **2026-11-16**. Links are pinned to the revision actually inspected. Document-internal dates belong to their authors.

- **[B-README](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/README.md)** [bullbin/xiaoyi_m1_re_liveview/README.md](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/README.md)
- **[B-UUID](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_ble/const_ble_uuid.py)** [bullbin/xiaoyi_m1_re_liveview/prot_ble/const_ble_uuid.py](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_ble/const_ble_uuid.py)
- **[B-BLE](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_ble/ble_keyhack.py)** [bullbin/xiaoyi_m1_re_liveview/prot_ble/ble_keyhack.py](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_ble/ble_keyhack.py)
- **[B-CMD](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_http/command_http.py)** [bullbin/xiaoyi_m1_re_liveview/prot_http/command_http.py](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_http/command_http.py)
- **[B-ENUM](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_http/const_http_enum_extra.py)** [bullbin/xiaoyi_m1_re_liveview/prot_http/const_http_enum_extra.py](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/prot_http/const_http_enum_extra.py)
- **[B-HTTP](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/debug_html.py)** [bullbin/xiaoyi_m1_re_liveview/debug_html.py](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/debug_html.py)
- **[B-UDP](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/udp_bitmap_decoder.py)** [bullbin/xiaoyi_m1_re_liveview/udp_bitmap_decoder.py](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/udp_bitmap_decoder.py)
- **[B-LICENSE](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/LICENSE)** [bullbin/xiaoyi_m1_re_liveview/LICENSE](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/LICENSE)
- **[P-README](https://github.com/protyposis/yi-mirrorless-firmware-tools/blob/b90b96c124a3b076fa0283404e6595a4a40d20d0/README.md)** [protyposis/yi-mirrorless-firmware-tools/README.md](https://github.com/protyposis/yi-mirrorless-firmware-tools/blob/b90b96c124a3b076fa0283404e6595a4a40d20d0/README.md)
- **[P-LICENSE](https://github.com/protyposis/yi-mirrorless-firmware-tools/blob/b90b96c124a3b076fa0283404e6595a4a40d20d0/LICENSE.md)** [protyposis/yi-mirrorless-firmware-tools/LICENSE.md](https://github.com/protyposis/yi-mirrorless-firmware-tools/blob/b90b96c124a3b076fa0283404e6595a4a40d20d0/LICENSE.md)
- **[E-README](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/README.md)** [echeetah/yi-m1-monitor/README.md](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/README.md)
- **[E-LIVE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/live-testing-findings.md)** [echeetah/yi-m1-monitor/fable research/live-testing-findings.md](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/live-testing-findings.md)
- **[E-PTP](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/ptp-mtp-attack-surface.md)** [echeetah/yi-m1-monitor/fable research/ptp-mtp-attack-surface.md](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/ptp-mtp-attack-surface.md)
- **[E-VIDEO](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/rcvideoformatset-solved.md)** [echeetah/yi-m1-monitor/fable research/rcvideoformatset-solved.md](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/rcvideoformatset-solved.md)
- **[E-CMD](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/Commands.swift)** [echeetah/yi-m1-monitor/yi-m1-ios/YiM1Core/Sources/YiM1Core/Commands.swift](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/Commands.swift)
- **[E-FILE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/CameraFile.swift)** [echeetah/yi-m1-monitor/yi-m1-ios/YiM1Core/Sources/YiM1Core/CameraFile.swift](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/CameraFile.swift)
- **[E-HTTP](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/HTTPClient.swift)** [echeetah/yi-m1-monitor/yi-m1-ios/YiM1Core/Sources/YiM1Core/HTTPClient.swift](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/HTTPClient.swift)
- **[E-BLE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/BLEPairing.swift)** [echeetah/yi-m1-monitor/yi-m1-ios/YiM1Core/Sources/YiM1Core/BLEPairing.swift](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/BLEPairing.swift)
- **[E-LICENSE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/LICENSE)** [echeetah/yi-m1-monitor/LICENSE](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/LICENSE)
- **[F-README](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/README.md)** [xiaobaiwud12/yi-m1-controller-app/README.md](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/README.md)
- **[F-PROTOCOL](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/docs/PROTOCOL.md)** [xiaobaiwud12/yi-m1-controller-app/app/docs/PROTOCOL.md](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/docs/PROTOCOL.md)
- **[F-LICENSE](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/LICENSE)** [xiaobaiwud12/yi-m1-controller-app/LICENSE](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/LICENSE)
- **[F-NOTICE](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/NOTICE)** [xiaobaiwud12/yi-m1-controller-app/NOTICE](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/NOTICE)
- **[Z-README](https://github.com/zeroa234/XIAOYI_M1/blob/d4594656b2654877f0e84323adaaf2698cbb0cc7/README.md)** [zeroa234/XIAOYI_M1/README.md](https://github.com/zeroa234/XIAOYI_M1/blob/d4594656b2654877f0e84323adaaf2698cbb0cc7/README.md)
- **[A-README](https://github.com/feletoch/Yi-M1-Android-app-patch/blob/9e084ed549f75ae4d7ec96e304ad57913e1f5667/README.md)** [feletoch/Yi-M1-Android-app-patch/README.md](https://github.com/feletoch/Yi-M1-Android-app-patch/blob/9e084ed549f75ae4d7ec96e304ad57913e1f5667/README.md)
- **[ACTION-README](https://github.com/dr1s/yiac/blob/9a8709687d6ac30e0270ebad66baaa5bc3f81c2c/README.md)** [dr1s/yiac README](https://github.com/dr1s/yiac/blob/9a8709687d6ac30e0270ebad66baaa5bc3f81c2c/README.md)
- **[ACTION-CODE](https://github.com/dr1s/yiac/blob/9a8709687d6ac30e0270ebad66baaa5bc3f81c2c/yiac/api.py)** [dr1s/yiac `yiac/api.py`](https://github.com/dr1s/yiac/blob/9a8709687d6ac30e0270ebad66baaa5bc3f81c2c/yiac/api.py)
- **[AMBA-README](https://github.com/Informatic/ambarpc/blob/7ec9210c38f4510a4de053e473e93afb26a20380/README.md)** [Informatic/ambarpc README](https://github.com/Informatic/ambarpc/blob/7ec9210c38f4510a4de053e473e93afb26a20380/README.md)

## Implementation follow-up — read-only connection status (2026-11-17)

For issue #2, `GetCameraStatus` was selected as the staged harmless request, not media listing or a mode/settings change. Original app status parsing reads string numeric `batteryLevel` and `SurplusPhotoCnts`; the shared envelope uses `code`/`data`. Echeetah's pinned [HTTP client](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/yi-m1-ios/YiM1Core/Sources/YiM1Core/HTTPClient.swift) and [author-reported findings](https://github.com/echeetah/yi-m1-monitor/blob/e1fbaeba7f2be2320794e61523d0cff799d739e5/fable%20research/live-testing-findings.md) corroborate HTTP 200 plus JSON code 200. Flutter's pinned [protocol notes](https://github.com/xiaobaiwud12/yi-m1-controller-app/blob/dc3a659dcee01d075ddc7bb3c4d3dede7986653e/app/docs/PROTOCOL.md) supply the string-field shape on 3.1-cn. This remains a source-informed 3.2-int schema assumption, not our real-camera HTTP result. The spare-photo count is not used as a filename listing or empty-card result.

BLE ordering remains `da4` → fresh `da6` → `da5` ASCII `ON` → BLE cleanup → network association. Bullbin omits the response argument for `da5`, but its [requirements](https://github.com/bullbin/xiaoyi_m1_re_liveview/blob/52deda7d7ed390c2edc1a3d0c2383dc7cdf7c9ca/requirements.txt) pin Bleak 0.21.1, whose [selection logic](https://github.com/hbldh/bleak/blob/v0.21.1/bleak/__init__.py) prefers advertised `write`, otherwise without-response. It is not evidence of a universal fixed write mode. The staged adapter preflights advertised capabilities, sends `ON` once and has no blind fallback. No new camera `da5` or HTTP operation ran during this offline implementation. See [implementation/validation limits](../development/connection.md).
