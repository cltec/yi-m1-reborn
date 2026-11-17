# YI M1 original app identity and archives

Observed **2026-11-16 UTC**. Scope: the YI **M1 Micro Four Thirds mirrorless camera**, not YI Home, YI Action, dash cameras, or Apple's M1 processor. This reference separates vendor evidence, mirror metadata, locally inspected bytes, and untested claims.

## Result

The official M1 Android app is **YI Mirrorless**, package **`com.xiaoyi.mirrorlesscamera`**. The official iOS app is **YI Mirrorless - Remote Control**, Apple ID **`1111129550`**, bundle ID **`com.xiaoyi.YIMirrorlessCamera`**. The old English vendor download page still serves both exact store links [S1].

The Google Play URL returned **404** in this session. The US Apple listing and lookup API returned **200** and still described version **3.1.1**, dated **2019-01-22** [S2, S3]. A working listing is not proof that installation succeeds on a particular account, region, or modern phone. No installation was attempted.

An Android APK was successfully downloaded from APKPure Lite. Its manifest identifies **3.1.6_20190517**, version code **51**. This is an original-app candidate from a third-party archive, not a vendor-hosted download or an independently audited safe executable. The package, version, certificate metadata, and an independent community project's stated base hash all agree.

## Official identity and original vendor downloads

| Evidence | Observed result |
|---|---|
| [English M1 product page](https://api.yitechnology.com/yi-m1-mirrorless-camera) | HTTP 200; describes M1 and BLE connection that turns on Wi-Fi for photo downloads. Links to Firmware & App. |
| [English Firmware & App](https://api.yitechnology.com/firmware/index/class/mirrorless) [S1] | HTTP 200; Mobile App icons point to `https://itunes.apple.com/app/id1111129550?mt=8` and `https://play.google.com/store/apps/details?id=com.xiaoyi.mirrorlesscamera`. This directly ties both IDs to M1. |
| [Google Play](https://play.google.com/store/apps/details?id=com.xiaoyi.mirrorlesscamera) | HTTP 404, “requested URL was not found.” This is a point-in-time regional/session observation, not proof of removal from every country. |
| [Apple US listing](https://apps.apple.com/us/app/yi-mirrorless-remote-control/id1111129550) [S2] | HTTP 200; developer Shanghai Xiaoyi Technology Co., Ltd.; version 3.1.1; iOS 9.0 minimum. |
| [Apple lookup](https://itunes.apple.com/lookup?id=1111129550&country=us) [S3] | HTTP 200; `trackId:1111129550`, `bundleId:com.xiaoyi.YIMirrorlessCamera`, `version:3.1.1`, `currentVersionReleaseDate:2019-01-22T15:38:30Z`. |
| [Chinese M1 product page](https://www.xiaoyi.com/weidan.html) | HTTP 200; Chinese M1 page links to the download page below. |
| [Chinese M1 downloads](https://www.xiaoyi.com/weidan_download.html) [S4] | HTTP 200; firmware/manual links only in observed HTML, no direct APK. Lists body V3.2-cn, dated 2018-09-05. |

The English page [S1] exposes these **vendor-linked firmware/manual URLs**, not Android packages. They were recorded from HTML but **not downloaded or tested** in this app-archive investigation:

- Body V3.0-int, page date 2017-10-30: <https://yitechnology-website.oss-us-west-1.aliyuncs.com/images/Firmware+V3.0-int.zip>
- 42.5mm lens V1.1: <https://yitechnology-website.oss-us-west-1.aliyuncs.com/images/Yimirrorless/42.5mmF1.8LensFirmwareV1.1-int.zip>
- 12–40mm lens V1.1: <https://yitechnology-website.oss-us-west-1.aliyuncs.com/images/Yimirrorless/Firmware/12-40mmF3.5-5.6lensFirmwareV1.1_int.zip>
- English M1 manual: <https://yitechnology-website.oss-us-west-1.aliyuncs.com/images/Yimirrorless/YI-M1.pdf>
- Chinese body V3.2-cn from [S4]: <https://xiaoyi-publicfiles.oss-cn-shanghai.aliyuncs.com/firmware/download/3.2-cn.zip>

Do not substitute Chinese firmware for international firmware merely because its version is higher. Regional compatibility was not established here.

**No direct vendor APK was found** on the two confirmed download pages. App-store links are the proven original distribution pointers. Guessed `www.yitechnology.com/yi-m1-mirrorless-camera`, `/yi-m1-mirrorless-camera-app`, and `/download.html` returned 404. `www2.yitechnology.com` M1 page probes returned 502. The working `api.yitechnology.com` pages matter: the failed `www` probes alone would incorrectly suggest all original material is gone. `www.xiaoyi.com/yi_m1/download.html` returned a 23-byte PHP fragment, not a usable download page; this was a guessed path, not an archival source.

## Android archive and historical versions

Working third-party archive pages:

- Listing [S5]: <https://apkpure.net/yi-mirrorless/com.xiaoyi.mirrorlesscamera>
- Versions [S6]: <https://apkpure.net/yi-mirrorless/com.xiaoyi.mirrorlesscamera/versions>
- Latest download details [S7]: <https://apkpure.net/yi-mirrorless/com.xiaoyi.mirrorlesscamera/download>
- **Successful APK request URL:** <https://d.apkpure.net/b/APK/com.xiaoyi.mirrorlesscamera?version=latest>

The archive labels the developer “YI Technologies, Inc.” Its description explicitly names **YI-M1 MILC**, Sony IMX269, Master Guide, and BLE. This is not an unrelated YI Home/Action entry. Archive marketing such as “virus-free” is **not** a conclusion of this investigation.

The version page [S6] exposed the following entries. Dates are **archive-listed update dates**, not independently established build dates. Only the newest APK was acquired and manifest-checked. This is the ten-entry list visible in the retrieved page, not a claim of exhaustive release history; `?page=2` returned the same list.

| Version name | Version code (archive) | Archive date |
|---|---:|---|
| 3.1.6_20190517 | 51 | 2019-05-20 |
| 3.1.5_20190507 | 50 | 2019-05-08 |
| 3.1.4_20190118 | 49 | 2019-01-18 |
| 3.1.3_20180830 | 48 | 2018-09-05 |
| 3.1.1_20180108 | 46 | 2018-01-12 |
| 3.0.0_20171031 | 43 | 2017-11-04 |
| 2.0.1_20170512 | 41 | 2017-05-16 |
| 2.0.0_20170412 | 40 | 2017-04-13 |
| 1.1.9_20170216 | 39 | 2017-02-27 |
| 1.1.8_20170124 | 38 | 2017-01-29 |

Observed older-version links use the exact base `https://apkpure.net/yi-mirrorless/com.xiaoyi.mirrorlesscamera/download/` followed by one of the nine older version names above. These links were present in the HTML; their individual APK downloads were **not tested**. Example decompile-comparison candidate: <https://apkpure.net/yi-mirrorless/com.xiaoyi.mirrorlesscamera/download/2.0.0_20170412>. The 2.0.0 archive notes introduce remote control and require camera firmware v2.0-int or later. The 3.0.0 notes add RAW/video downloads and compatibility with firmware 3.0. These are release-note claims, not camera test results.

Acquisition blockers on other paths: `apkpure.com/search` returned a Cloudflare 403; **`apkpure.net` worked without bypassing a challenge**. `apkcombo.com/search/yi-mirrorless` redirected to a DropCatch domain page and was not a useful archive. A narrow Wayback CDX request for `yitechnology.com/*mirrorless*` returned `[]`; that narrow result does not establish that Wayback has no relevant captures.

## Acquired APK: provenance and static metadata

Local file (excluded from git):

```text
research-artifacts/yi-mirrorless-3.1.6_20190517-apkpure.apk
Size:   23076298 bytes
SHA256: 2b73f7805dfcb3bde0efbe3f8286958ba849ab614317e9c0814985ea8f927001
```

The successful request redirected to an expiring signed `data.winudf.com` URL. The full observed redirect URL, query, acquisition timestamp, and source URLs are preserved in `research-artifacts/yi-mirrorless-3.1.6_20190517-provenance.json`; the stable request URL above is the reproducible starting point. The path component of that observed redirect was:

```text
https://data.winudf.com/apk/Y29tLnhpYW95aS5taXJyb3JsZXNzY2FtZXJhXzUxXzhkZWRjYmY5
```

Manifest values parsed directly from the APK's binary Android XML:

| Field | Value |
|---|---|
| Package | `com.xiaoyi.mirrorlesscamera` |
| `versionName` / `versionCode` | `3.1.6_20190517` / `51` |
| `minSdkVersion` / `targetSdkVersion` | `19` / `26` |
| Application class | `com.xiaoyi.mirrorlesscamera.common.MApplication` |
| Required hardware | `android.hardware.bluetooth_le` |
| Relevant declared permissions | Internet; Bluetooth/Bluetooth admin; Wi-Fi state/change; coarse/fine location; external storage read/write. |

The archive contains 1,788 ZIP entries, one `classes.dex`, binary `AndroidManifest.xml`, `resources.arsc`, and eight native libraries **only under `lib/armeabi-v7a/`**:

```text
libactionshot.so  libframerecv.so  libgpuimage-library.so  libhdr.so
libimagepipeline.so  libimgenhance.so  libink.so  libwb.so
```

The 32-bit-only ABI is an important compatibility constraint. No claim is made that this APK installs on an arm64-only device. Assets include Master Guide images/HTML, `ShareSDK.xml`, and Chinese/international agreement/privacy HTML. No account login or network behavior was tested.

### Signing evidence and limits

`META-INF/CERT.RSA` is present. OpenSSL parsed a 2048-bit RSA certificate, SHA256-with-RSA, with:

- Subject/issuer: `C=86, ST=Shanghai, L=Shanghai, O=Shanghai Xiaoyi Technology Company Limited, OU=Mirrorless department, CN=Xiaoyi`.
- Validity: 2016-09-13 08:29:00 UTC to 2041-09-07 08:29:00 UTC.
- **Certificate SHA-1:** `7d9ca643146107519b6bb4d0123d2b4a49e8aa77`.

This matches the “Signature” fingerprint published by APKPure's download-details page [S7]. It is a **certificate fingerprint**, not the APK content hash. Subject names in a self-signed certificate do not independently prove vendor ownership.

`jarsigner -verify -verbose -certs` exited 0 and reported **“jar verified.”** It also warned about a self-signed/untrusted certificate, absent timestamp, and different `JarFile` versus `JarInputStream` signing views (manifest not seen through `JarInputStream`). The full output is preserved locally. This is v1/JAR verification, **not a clean Android `apksigner` verdict or malware audit**. No v2/v3 signature verification or runtime acceptance test was performed.

### Static protocol corroboration and decompile entry points

A separate [original-app code-flow analysis](original-app-analysis.md) now documents completed JADX inspection of this same APK. The string-only evidence and limits below describe the archive-inspection step, not the scope of that separate analysis.

A direct DEX string-table parse found the following literals in the acquired original-app candidate:

- HTTP: `http://192.168.0.10/?data=`, `http://192.168.42.1/DCIM/`, `GetFileList`, `GetFileInfo`, `{"command":"GetFile","path":"`, and `","resulotion":"Thumbnail"}`. The misspelled key **`resulotion`** is present in the original bytes.
- Pairing/Wi-Fi: `PairCamera`, `UnPairCamera`, `connectToEnableWifi`, `received pairing response`, and `received remove pair response `.
- BLE UUID strings have first fields `41106da0`, `41106da1`, `41106da2`, `41106da3`, `41106da4`, `41106da5`, `41106da6`, `41106da7`, `41106da9`, `41106dac`, `41106dad`, `41106dae`, `41106daf`, and `41106dd9`; every one has suffix `-25ad-477b-a884-5038b6de4649`. The complete exact strings are in the local string dump. CCCD `00002902-0000-1000-8000-00805f9b34fb` also appears.
- Control literals include `RCStartRemoteCtl`, `RCStopRemoteCtl`, `RCGetCameraCfg`, `RCDoShooting`, `RCDoFocus`, `RCISOSet`, `RCShutterSpeedSet`, `RCFileFormatSet`.
- Useful class descriptors include `com.xiaoyi.mirrorlesscamera.activity.CameraBindingActivity`, `CameraConnectActivity`, `LiveViewActivity`, `common.WifiAdmin`, and `view.LiveView`. `lib/armeabi-v7a/libframerecv.so` is a native live-view investigation candidate.

These literals independently corroborate that BLE/Wi-Fi pairing and HTTP album/control code exist in the original app. **A string table does not establish UUID roles, packet layout, call order, active IP selection, port use, or that a server still works.** No connection was made to these extracted endpoint literals. Detailed protocol conclusions need code-flow analysis and camera testing, documented separately.

## iOS history

Apple's current public US page [S2] exposes this version history, transcribed as ISO dates. This is store metadata, not downloaded IPA inspection:

| Date | Version | Date | Version |
|---|---|---|---|
| 2019-01-22 | 3.1.1 | 2018-09-04 | 3.1.0 |
| 2018-04-23 | 3.0.1 | 2017-10-28 | 3.0.0 |
| 2017-09-29 | 2.0.3 | 2017-04-21 | 2.0.1 |
| 2017-04-13 | 2.0.0 | 2017-02-17 | 1.1.9 |
| 2017-01-24 | 1.1.8 | 2017-01-13 | 1.1.7 |
| 2017-01-03 | 1.1.6 | 2016-12-09 | 1.1.5 |
| 2016-11-21 | 1.1.4 | 2016-11-01 | 1.1.3 |
| 2016-10-21 | 1.1.2 | 2016-10-18 | 1.1.1 |
| 2016-10-15 | 1.1.0 | 2016-10-07 | 1.0.6 |
| 2016-09-28 | 1.0.5 | 2016-09-20 | 1.0.0 |

Apple's lookup `releaseDate` is 2016-10-16 while the visible history includes earlier versions. Preserve that discrepancy rather than treating one field as a worldwide first-release date. Version 3.1.0's store notes say it fixes iOS 11 live preview and requires latest camera firmware. No public vendor IPA download was found or acquired. Store/account-based lawful access is the starting point; no DRM removal or account-sharing route was attempted.

## Separate community-patched original app

**Not the original release and not a clean-room replacement:** <https://github.com/feletoch/Yi-M1-Android-app-patch> [S8].

The inspected `master` README calls it an unofficial AI-assisted rebuild of original 3.1.6. It claims replacement of native live-view/image-buffer code with Java, `targetSdkVersion` 28, an independent signing key, and successful Android 16/API36 arm64-only camera tests. It acknowledges original app code in the patched APK and non-working native photo editing. **These device/functional claims were not reproduced.**

Provenance observations:

- Repository created 2026-10-28, according to GitHub API [S9].
- README's required original base SHA-256 is **`2b73f7805dfcb3bde0efbe3f8286958ba849ab614317e9c0814985ea8f927001`**, exactly matching this investigation's APKPure download.
- GitHub release `release`, published 2026-10-28T11:37:58Z, asset `yi-3.1.6-patched.apk`, 43,925,469 bytes [S10]. GitHub-reported digest: `16cb5d67568413131cbc3f71ef0168f7627ea1d30db16962b2b2ea8d752ee2fe`. This digest was **not locally recomputed**, because the patched binary was not downloaded.
- Exact published asset URL: <https://github.com/feletoch/Yi-M1-Android-app-patch/releases/download/release/yi-3.1.6-patched.apk>.
- Useful comparison sources exist under `build/decoded-patch/smali/com/xiaoyi/mirrorlesscamera/` and `build/patch-src/com/xiaoyi/mirrorlesscamera/`, including `view/UdpJpegReceiver.java`. They are modified comparison material, not evidence of unchanged vendor behavior.
- GitHub metadata reports `license: null`; `/license` returns 404; the recursive tree showed no top-level license file. README's Legal section gives no explicit reuse license for the original app or patches. **Do not assume an open-source license or permission to redistribute the patched/vendor code.**

The README's broad statement that the original is “no longer distributed by its vendor” is not adopted as a universal fact: Apple's official public listing still responded during this investigation. A working listing still does not prove installability.

## Safe and lawful analysis boundaries

- Network work used ordinary HTTPS GETs via Python `requests`. ZIP, binary Android XML, and DEX string tables were read as data with Python standard-library parsing; OpenSSL and the installed JDK `jarsigner` inspected certificate/signature data. No APK, APK-contained code, vendor app, or patched app was executed or installed. No dependencies were installed into the REPL.
- The original APK is copyrighted proprietary software. Availability on a mirror is not a redistribution license. Keep APKs, decompiled code, certificates, raw strings, and source snapshots in the ignored local `research-artifacts/` directory, not git. A clean implementation should use necessary interoperability facts and avoid copying UI, images, native libraries, decompiled implementation, or embedded credentials.
- Ownership of hardware does not automatically settle local law on decompilation, contract terms, copyright, or circumvention. Confirm the applicable interoperability exception/license before distributing derived work; seek legal advice where needed. This report is technical research, not a legal opinion.
- Treat both old original and patched APKs as untrusted. Signature/hash agreement establishes consistency, not absence of harmful behavior. Any later dynamic testing should use a disposable isolated device/profile, no personal accounts, and only the researcher's own camera/network.
- No configuration or application constants were changed by this investigation. No camera firmware was flashed, no cloud authentication was bypassed, and no extracted cloud endpoint was queried.

## Local reproducibility artifacts

Alongside the APK, `research-artifacts/` contains `*-provenance.json`, `*-manifest.json`, `*-files.txt`, `*-dex-strings.txt`, `*-CERT.RSA`, `*-cert.pem`, and `*-jarsigner.txt`. `app-archive-sources/` stores the observed vendor, APKPure, Apple, and community-project responses. These files are local evidence, not committed project assets.

## Sources

All URLs below were retrieved on **2026-11-16 UTC**. HTTP observations above apply to this session only.

- **S1:** <https://api.yitechnology.com/firmware/index/class/mirrorless> — original vendor store links and firmware/manual pointers.
- **S2:** <https://apps.apple.com/us/app/yi-mirrorless-remote-control/id1111129550> — current official public US listing and version history.
- **S3:** <https://itunes.apple.com/lookup?id=1111129550&country=us> — official Apple metadata. Discovery query: <https://itunes.apple.com/search?term=yi%20mirrorless&entity=software&limit=20>.
- **S4:** <https://www.xiaoyi.com/weidan_download.html> — original Chinese M1 firmware/manual download page.
- **S5:** <https://apkpure.net/yi-mirrorless/com.xiaoyi.mirrorlesscamera> — third-party M1 app archive identity.
- **S6:** <https://apkpure.net/yi-mirrorless/com.xiaoyi.mirrorlesscamera/versions> — archive version list/release notes.
- **S7:** <https://apkpure.net/yi-mirrorless/com.xiaoyi.mirrorlesscamera/download> — package/ABI/certificate fingerprint and actual APK link.
- **S8:** <https://raw.githubusercontent.com/feletoch/Yi-M1-Android-app-patch/master/README.md> — patched-app author claims, base hash and legal notice.
- **S9:** <https://api.github.com/repos/feletoch/Yi-M1-Android-app-patch> and <https://api.github.com/repos/feletoch/Yi-M1-Android-app-patch/license> — repository provenance/license metadata.
- **S10:** <https://api.github.com/repos/feletoch/Yi-M1-Android-app-patch/releases> — published patched-APK asset metadata, not a local binary test.
