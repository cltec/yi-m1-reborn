# Original YI Mirrorless app: static protocol analysis

Analysis date: **2026-11-16**. This reference records facts recovered from one archived Android application. It is not a verified specification for every M1 firmware.

## Input, tool and limits

- Package: `com.xiaoyi.mirrorlesscamera`.
- App version: `3.1.6_20190517`, version code `51`.
- APK acquired from APKPure, not directly from the manufacturer. See [archive provenance and certificate details](app-archives.md).
- Input SHA-256: `2b73f7805dfcb3bde0efbe3f8286958ba849ab614317e9c0814985ea8f927001`.
- Input size: **23,076,298 bytes**.
- Tool: upstream **jadx 1.5.6** from https://github.com/skylot/jadx/releases/tag/v1.5.6 . Tool ZIP SHA-256 `545ea2be9c242511bc145755cf4bda2485ade42966e096f8b4d3da2a230e8974` matched the digest in the GitHub release API before use.
- Static decompilation completed with **exit code 0** and generated **4,111 Java files**. This does not prove every reconstructed method is correct. The progress log counted 2,574 top-level processing units; it is not a contradictory count of generated files.
- Neither the app nor its native libraries were executed. No phone/camera connection, packet capture, firmware analysis, native-library disassembly or complete security audit was performed.

The tool and all reconstructed source remain in gitignored `research-artifacts/`. Only derived protocol facts and an [analysis manifest](evidence/original-app-analysis.json) are included in the research documents. The original app remains proprietary; its availability is not an open-source license or permission to redistribute its code/assets.

Reproduction command, from the repository root after obtaining the same input and verified tool:

```text
java -Xmx2g -cp 'research-artifacts/tools/jadx-1.5.6/lib/*' jadx.cli.JadxCLI --no-res --threads-count 4 --output-dir 'research-artifacts/jadx-original-app' 'research-artifacts/yi-mirrorless-3.1.6_20190517-apkpure.apk'
```

`--no-res` skips resource decoding, not Java decompilation. This process inspected the APK as data; it did not launch an Android app. Generated names/line numbers below belong to this exact analysis, not original vendor source filenames or a public source release.

## BLE pairing and Wi-Fi setup

Generated class `com/xiaoyi/mirrorlesscamera/common/d.java` is marked `BleManager.java` in recovered source metadata.

| Observation | Local evidence |
| --- | --- |
| Camera service is `41106dd9-25ad-477b-a884-5038b6de4649`. | UUID fields near lines 45–65 |
| Firmware info is read from `41106da2-…`; fields are protocol version, body version, optional region, optional lens version. | Read callback near lines 659–681 |
| Initial pairing subscribes to `41106da7-…`, then writes to `41106da0-…`. | Read callback near lines 686–690 |
| Pairing payload is decimal `<protocol>,<reference-id>,android`; the ID uses `Random.nextInt(99999)`, hence 0…99998. | Method `s()`, near lines 868–873 |
| A non-empty `da7` notification is retained as the token; empty payload is treated as pairing refusal. | Notification callback near lines 230–241 |
| Session payload to `41106da4-…` is `<protocol>,<reference-id>,<decimal-crc32>`. CRC32 is updated with bytes of literal `1`, then reference ID, then token. | Method `t()`, near lines 875–883 |
| A successful session write leads to reading `41106da6-…`; comma-separated values are stored as Wi-Fi SSID/password. | Write/read callbacks near lines 588–591 and 639–658 |
| Enabling Wi-Fi writes ASCII `ON` to `41106da5-…`. | Method `j()`, near lines 1013–1020 |
| Optional `41106daf-…` notifications, `41106dae-…` notifications and writing `3` to `41106dad-…` are present. | Read callback and `f()`, near lines 694–706 |

UUID suffix for abbreviated entries: `-25ad-477b-a884-5038b6de4649`.

The app queues GATT operations. Its write path calls Android `writeCharacteristic()` without an explicit `setWriteType()` in this class. This does **not** independently establish which write mode works on every firmware/OS/plugin. Community clients report different behavior; target-device testing remains necessary.

The app contains region/protocol-version checks. These are client behavior, not proof that international and Chinese camera hardware necessarily require different wire protocols. Token storage suggests the original app supports session reuse; successful reuse in a replacement app has not been tested here.

CRC32 is an error-detection checksum, not a cryptographic MAC. Do not describe the recovered exchange as modern cryptographic authentication. Camera-screen confirmation and pairing replacement risks remain important; see [protocol prior art](protocol-prior-art.md).

## Important correction: camera time synchronization

`BleManager.k()` writes an ASCII decimal value to **`41106dac-…`**, but it does **not** directly send `System.currentTimeMillis()/1000` in this APK.

Instead, it calls `TimeUtil.a()/1000`. The generated helper is `com/xiaoyi/mirrorlesscamera/b/p.java`, marked `TimeUtil.java`. Its no-argument `a()` obtains the current `Calendar`, adds `Calendar.ZONE_OFFSET + Calendar.DST_OFFSET` in milliseconds, and returns the resulting time in milliseconds. The decompiled numeric fields are `14` (millisecond), `15` (zone offset), and `16` (DST offset).

**Derived meaning:** the decimal seconds are shifted by the phone's current timezone/DST offset, effectively encoding local wall-clock time as epoch-like seconds. They are not plain UTC Unix seconds except in a zero-offset timezone.

This directly qualifies community notes that simplify the payload to plain Unix epoch seconds. Before implementing time sync, validate the camera's displayed time and resulting EXIF timestamps in a non-UTC timezone and around DST changes. Do not change the camera clock merely to test browsing/download. No claim about the physical presence/absence of RTC hardware follows from this app code.

## File-list request and original app pagination

Generated `com/xiaoyi/mirrorlesscamera/http/camera/b.java`, marked `CameraHttpApi.java`, builds this logical request near lines 80–92:

```json
{"command":"GetFileList","range_start":1,"range_end":60,"filetype":"all"}
```

It uses the base **`http://192.168.0.10/?data=`**, followed by serialized JSON. The request factory in `http/camera/c.java` stores range arguments as Java integers; this is evidence for numeric JSON range values in this original app. Some community clients instead serialize them as strings.

`common/e.java`, marked `CameraAlbumManager.java`, near line 157 supplies:

- first index: **`page * 60 + 1`**;
- last index: **`(page + 1) * 60`**.

Thus the original gallery uses **one-based ranges, 60 entries per page**. A separate path requests **1…1** near line 299. This corroborates the Flutter implementation's choice. It does not prove the firmware rejects a different valid range such as 0…9999, nor settle all large-card behavior.

## Preview and original download URLs

`CameraAlbumManager` near lines 180–207 reads list-entry fields:

- `path`;
- `date`;
- `protectStatus`;
- `filetype`.

It constructs three forms of `GetFile` URL from the same camera-returned path/date:

```json
{"command":"GetFile","path":"<camera-returned path>","date":"<camera-returned date>","resulotion":"Thumbnail"}
{"command":"GetFile","path":"<camera-returned path>","date":"<camera-returned date>","resulotion":"MidThumb"}
{"command":"GetFile","path":"<camera-returned path>","date":"<camera-returned date>","resulotion":"Original"}
```

**`resulotion` is deliberately misspelled in the original app.** The whole JSON string is URL-encoded with Java `URLEncoder.encode(..., "UTF-8")` and appended to the same HTTP base. Keep raw JSON and its URL-encoded wire representation distinct.

The app stores these separately as thumbnail, preview and original URLs. Other app paths build a `GetFile` request without `date`, so `date` should not be asserted universally mandatory from gallery code alone.

File-type branches include `video`, `panorama`, `raw`, `rawJpeg`, and a default normal-image case. These branches establish client-side handling, not that every firmware can return every type or generate every thumbnail. DNG/JPEG original-byte integrity and exact RAW+JPEG pairing behavior still need tests.

`CameraHttpApi` also has `GetFileInfo` with a `path` field. It sets `Connection: close` in the inspected request builder and uses a priority request queue. This supports a conservative serialized implementation; it is not an independent camera concurrency measurement.

## Live view is a separate path

Generated `com/xiaoyi/mirrorlesscamera/view/LiveView.java`, near lines 163–181, invokes a native receiver on **UDP 54321** for the small-packet branch. The Java image path treats the first **2048 bytes** of the assembled frame as metadata and decodes JPEG bytes after it. The older branch near lines 188–216 uses a Java UDP socket on the same port.

The native fragment assembler was not disassembled, so the exact 12-byte datagram header documented by public clients is **not independently established by this Java-only analysis**. See [protocol prior art](protocol-prior-art.md) for that attributed source evidence. Live view is not the same operation as downloading stored photographs, and need not be in the first app version.

## What this analysis establishes

It independently corroborates the M1 BLE handshake constants, local HTTP endpoint, original app pagination policy, preview/original request shapes and part of the UDP path. It also exposes a timezone adjustment omitted by some community descriptions.

It does **not** establish universal firmware support, modern-phone compatibility, secure transport, complete cloud independence of the original app UI, or successful photo download from the user's camera. The APK includes vendor/third-party cloud and analytics code; a replacement can evaluate the local protocol separately without copying those services.

No application implementation, camera setting, firmware or protocol constant was changed.
