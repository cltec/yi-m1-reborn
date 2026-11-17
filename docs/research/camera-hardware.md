# YI M1 camera hardware and wireless workflow

Retrieved **2026-11-16 UTC**. Scope: **Xiaoyi / YI-M1 Micro Four Thirds mirrorless digital camera**, not YI Home, Action, or dash cameras. This is a reference for building a replacement photo-transfer app. No physical camera was connected or tested.

## Main finding: Bluetooth pairs; Wi-Fi carries photo downloads

**Confirmed by manufacturer sources, not inferred from a generic YI camera protocol.** The official M1 product page says:

> “BLE Bluetooth establishes a reliable connection between YI-M1 and your smartphone. Wi-Fi is automatically turned on to quickly download and share photos from your camera.” [S1]

The official English manual, section 9, **printed page 15 / PDF page 10**, gives this sequence [S3]:

| Stage | Documented behavior |
|---|---|
| Preparation | Insert a memory card and turn on the camera. Enable the phone's Bluetooth and Wi-Fi. |
| Initial pairing | Open **YI Mirrorless App**. On its connection page, follow the prompt to pair the camera's Bluetooth. The manual says initial connection is “only necessary one time.” This does not establish permanent pairing across resets/reinstalls. |
| Network transition | After Bluetooth pairing succeeds, follow the prompt to connect the camera's Wi-Fi. |
| iOS-specific step | In system settings select camera network **`YI_M1_xxxxxx`**, paste the password into the password field, press Join, then return to YI Mirrorless. The manual directs pasting; it does not print a universal password. |
| Album access | Once the connection is complete, view the camera album. The manual also says the app downloads photos, uploads Master Guide templates, and updates firmware. |

**Implication for a replacement app:** a Bluetooth-only photo browser is not the documented architecture. Keep BLE connection/pairing and Wi-Fi album/download as separate capabilities. Exact GATT fields, HTTP endpoints, credentials, state restoration, and modern phone permissions are outside what the manual proves; see [protocol-prior-art.md](protocol-prior-art.md) and [device-validation.md](device-validation.md).

The December 2, 2016 **PCMag hands-on review** independently describes Android pairing as seamless and iOS as requiring manual connection to M1 Wi-Fi. It observed JPG-only browsing/download and in-camera RAW-to-JPG conversion [S8]. **Do not treat JPG-only as a timeless hardware limit:** later app release notes document RAW/video download and remote-control additions; see [app-archives.md](app-archives.md). The current vendor specs explicitly say remote control is supported with the latest app [S2].

## Compact hardware reference

Unless stated otherwise, these values are **manufacturer-published**, not independently measured [S1, S2].

| Component | Published specification |
|---|---|
| Product / mount | YI-M1; interchangeable-lens camera; **Micro Four Thirds (MFT)** mount; approximate 2× 35mm-equivalent focal-length factor. |
| Image sensor | **Sony IMX269**, about **20.16 million effective pixels**; 21.77 million total; 4:3. Manual specification gives 17.3 × 13 mm. |
| Native still output | **5184 × 3888** at 20M. Menu also offers 50M, 16M, 8M, 3M, VGA. Do not describe 50M mode as a native 50MP sensor. |
| Still formats | RAW and JPEG, EXIF v2.3; in-camera RAW-to-JPEG conversion. Simultaneous RAW+JPEG availability is firmware-dependent and not established by this spec table. |
| Autofocus | Contrast-detection; 81 AF points; single AF, continuous AF, touch focus/shoot; manual focus with focus peaking and magnification. |
| Exposure | Mechanical focal-plane shutter **1/4000–60 s**; ISO **100–25600**; P/A/S/M plus auto/scene, Bulb/Time; up to ±5 EV compensation. |
| Burst | Published **5 images/s**. |
| Display | Fixed **3-inch touchscreen**, approximately 1.04 million dots / 720RGB × 480. No built-in viewfinder (also confirmed in contemporary review [S9]). |
| Video | **3840 × 2160 at 30 fps**; 2048 × 1536 at 30; 1920 × 1080 at 60/30/24; 1280 × 720 at 60/30/24; 640 × 480 at 240. MPEG-4/H.264 video, AAC audio. |
| Audio | Stereo microphone; mono speaker. |
| Storage | One **SD/SDHC/SDXC** slot. Current web spec literally says “max 512g”; this likely means 512GB but is an imprecise vendor unit, not a tested capacity guarantee. |
| Wired interfaces | **Micro USB / USB 2.0** and **Micro HDMI**. USB charging confirmed in manual and PCMag [S3, S8]. |
| Wireless | **2.4GHz Wi-Fi**, Bluetooth **BLE 4.1** per current vendor web specs. Regulatory test details below. |
| Flash | External flash supported; 1/125s sync; no bundled/built-in flash per contemporary review [S8]. |
| Body dimensions | **113.5 × 64.3 × 33.6 mm**, excluding protrusions. |
| Weight | **280 g including battery** on manufacturer Features page [S4]. |
| Power | Rechargeable lithium battery; current vendor spec says about **380 CIPA shots**. PCMag's 2016 review cited 450 and observed less in use; do not mix historical ratings with current vendor table. |
| Kit lenses | YI **12–40mm f/3.5–5.6** (24–80mm equivalent) and YI **42.5mm f/1.8** (85mm equivalent); camera body and lens firmware are separate. |

### Source inconsistencies worth preserving

- The English manual's connection instructions say “micro SD card,” while its specification, the vendor web specification, and PCMag identify **SD/SDHC/SDXC**. Treat the connection-section wording as inconsistent, not proof of a microSD-only slot.
- The scanned 2016 manual specification appears to list **BLE 4.0**, and the 2016 FCC test report explicitly tests LE4.0. The current vendor web specification lists **BLE 4.1**. All establish **Bluetooth Low Energy**, not Bluetooth Classic file transfer; the precise marketed revision varies by source/date.
- Original 2016–2017 reviews describe early firmware, including lack of simultaneous RAW+JPEG. Such observations are useful historical evidence, not a substitute for checking the owner's installed firmware.

## Regulatory identity and radio capabilities

The correct filing is **FCC ID `2AFIB-DCM116`**, grant dated **2016-09-07**, equipment description **“Xiaoyi Mirror-less Camera”** [S5]. Both RF test reports explicitly identify **model `YI-M1`** and manufacturer Shanghai Xiaoyi Technology Co., Ltd., tying the filing to this camera rather than a similarly named product [S6, S7]. Filing copies were read through FCCID.io, a third-party mirror of regulatory documents; the FCC origin itself was not independently fetched.

| Evidence | Confirmed contents |
|---|---|
| Grant | US Part 15C ranges **2412–2462 MHz** and **2402–2480 MHz**. |
| BLE test report, **C160630R01-RPB1**, issued 2016-08-23, p5 | **Bluetooth LE4.0**, 2402–2480 MHz, 40 channels at 2MHz spacing, GFSK, 1Mbps, PCB antenna. This is an RF physical-layer rate, **not measured photo-transfer throughput**. |
| WLAN test report, **C160630R01-RPW**, issued 2016-08-23, p5 | **IEEE 802.11b/g/n HT20**, 2412–2462 MHz, 11 US channels; PCB antenna. No 5GHz capability is documented here. |
| WLAN report p8 | Describes a unique PCB antenna for Wi-Fi and Bluetooth. |

These engineering-sample compliance tests establish radio capabilities, not the camera's application-level protocol, connection limits, security, regional channel list outside the US, or modern-device compatibility.

### Regulatory documents / manual pointers

- Filing and grant: <https://fccid.io/2AFIB-DCM116>
- Manufacturer-submitted **11-page** FCC user manual, exhibit **3123461**, available 2016-09-07: <https://fccid.io/2AFIB-DCM116/User-Manual/Users-Manual-3123461>
- Direct mirror PDF for that exhibit: <https://fccid.io/m/973a1a02de31f692073d343962b068ecacf299d6d3127a1dd15e4d4ee8533437.pdf>
- BLE report exhibit **3123465**: <https://fccid.io/2AFIB-DCM116/Test-Report/Test-Report-BT-LE-3123465>
- WLAN report exhibit **3123466**: <https://fccid.io/2AFIB-DCM116/Test-Report/Test-Report-WLAN-3123466>

The FCC manual is **not the same byte stream** as the later 12-page official English PDF described below. Radio conclusions above come from the actual report text, not only the mirror's index metadata.

## Official support, manuals, and firmware

### Working manufacturer sources

The old English site remains readable under **`api.yitechnology.com`**. A failed `www` or `www2` URL does **not** mean the documents have vanished.

- English product: <https://api.yitechnology.com/yi-m1-mirrorless-camera>
- English specs: <https://api.yitechnology.com/yi-m1-mirrorless-camera-specs>
- English downloads: <https://api.yitechnology.com/firmware/index/class/mirrorless>
- Chinese downloads: <https://www.xiaoyi.com/weidan_download.html>

The English Firmware & App page links **YI Mirrorless** Android package `com.xiaoyi.mirrorlesscamera` and Apple app ID `1111129550`. These are not YI Home/Action apps. App availability, compatibility, and archive provenance are documented in [app-archives.md](app-archives.md).

### Official English manual

- Vendor listing release date: **2016-11-28**.
- Direct PDF: <https://yitechnology-website.oss-us-west-1.aliyuncs.com/images/Yimirrorless/YI-M1.pdf>.
- Retrieved successfully: **HTTP 200, application/pdf, 5,053,045 bytes, 12 PDF pages**.
- SHA-256: **`cdda5789fdd2bcfc5e5e81dfc4aa4159be9140a0fd2240dcce6e93d3d5e0a432`**.
- The pages are scanned/image-based two-page spreads. `pdftotext` yielded no useful text. The connection instructions were **read visually** on PDF p10 / printed p15; PDF p2 contains the specification table.
- PDF metadata: created/modified **2016-10-18**, CorelDRAW X6 / Corel PDF Engine. This differs from the vendor's publication/listing date, not necessarily a content contradiction.

### Firmware listings: versions are regional, and English page is stale

| Vendor listing | Listed version / release date | Exact vendor-linked download (not downloaded or flashed here) |
|---|---|---|
| English camera body | **V3.0-int**, **2017-10-30** | <https://yitechnology-website.oss-us-west-1.aliyuncs.com/images/Firmware+V3.0-int.zip> |
| English 42.5mm f/1.8 lens | **V1.1**, **2017-04-12** | <https://yitechnology-website.oss-us-west-1.aliyuncs.com/images/Yimirrorless/42.5mmF1.8LensFirmwareV1.1-int.zip> |
| English 12–40mm f/3.5–5.6 lens | **V1.1**, **2017-04-19** | <https://yitechnology-website.oss-us-west-1.aliyuncs.com/images/Yimirrorless/Firmware/12-40mmF3.5-5.6lensFirmwareV1.1_int.zip> |
| Chinese camera body | **V3.2-cn**, **2018-09-05** | <https://xiaoyi-publicfiles.oss-cn-shanghai.aliyuncs.com/firmware/download/3.2-cn.zip> |

**V3.0-int is only the newest version currently listed on the retrieved English page, not the latest known international firmware.** Existing implementation reports refer to cameras running **3.2-int**; see [protocol-prior-art.md](protocol-prior-art.md). This hardware investigation did not locate and verify a manufacturer-hosted 3.2-int binary or a complete release history. **`-cn` and `-int` are distinct labels; compatibility, interchangeability, safe downgrade, and cross-region flashing were not established.** Do not install the Chinese package just because its number is higher. No upgrade is needed merely to conduct this research.

The current vendor specs describe body upgrades through the YI-M1 app and lens upgrades through app/camera [S2]. This is not a verified recovery or SD-card flashing procedure.

### Current support limitations

At retrieval, old `help.yitechnology.com/hc/en-us/...` routes served a **Kami** support application rather than original M1 help articles. Guessed old English `www` M1 paths returned 404 and `www2` paths returned 502. These are access observations, not proof that all support ceased or every archive is unavailable. The confirmed manufacturer pages/PDF above still worked.

## Local reproducibility evidence

Ignored local directory **`research-artifacts/camera-manual/`** contains:

- `YI-M1-official-2016-11-28.pdf`: original manufacturer-linked PDF, hash above.
- `provenance.json`: original/final URL provenance, retrieval date, byte size, hash, relevant pages, and extraction caveat.
- `manual-pdf-page-10-printed-pages-15-16.jpg`: 120dpi rendered spread with Bluetooth → Wi-Fi instructions.
- `manual-pdf-page-02-specification-contents.jpg`: rendered specification/contents spread.
- Snapshots of working English product/spec/download HTML, Chinese download HTML, FCC grant HTML, and full text extractions of the two RF reports.

The manual and derived images are evidence kept locally, not a license to redistribute vendor assets. No project/application constants were changed; no firmware package was executed, downloaded, or flashed. No claim here is a physical-device test result.

## Source register

All sources below were retrieved **2026-11-16 UTC**. Manufacturer pages/PDF were fetched directly over HTTPS. Some FCC mirror and review pages blocked direct requests; public page/report text was retrieved through `https://r.jina.ai/` using the same exact target URL. A proxy's metadata publication timestamp is not the source document's issue date.

- **S1 — Manufacturer product page:** <https://api.yitechnology.com/yi-m1-mirrorless-camera>. Explicit BLE → Wi-Fi photo-download statement, Sony IMX269 identity.
- **S2 — Manufacturer specification:** <https://api.yitechnology.com/yi-m1-mirrorless-camera-specs>. Hardware table and current remote-control/firmware statements.
- **S3 — Manufacturer English manual:** <https://yitechnology-website.oss-us-west-1.aliyuncs.com/images/Yimirrorless/YI-M1.pdf>. Linked by <https://api.yitechnology.com/firmware/index/class/mirrorless>. Printed p15 / PDF p10: wireless connection; PDF p2: specs.
- **S4 — Manufacturer Features page:** <https://api.yitechnology.com/yi-m1-mirrorless-camera-features>. 280g including battery.
- **S5 — FCC filing mirror:** <https://fccid.io/2AFIB-DCM116>. Grant and exhibit index. Retrieval proxy: <https://r.jina.ai/https://fccid.io/2AFIB-DCM116>.
- **S6 — BLE RF report PDF:** <https://fccid.io/m/2c632709bc1ef23f21e5c342bb73a3c7b9fb91015bd827ef79946a6dde9234da.pdf>. 39 pages, report C160630R01-RPB1, especially pp1, 5. Retrieval proxy: <https://r.jina.ai/https://fccid.io/m/2c632709bc1ef23f21e5c342bb73a3c7b9fb91015bd827ef79946a6dde9234da.pdf>.
- **S7 — WLAN RF report PDF:** <https://fccid.io/m/23de7d00a8b67c921eb44b2cc2b712d662633abb2997076e431e92e09d42ff61.pdf>. 66 pages, report C160630R01-RPW, especially pp1, 5, 8. Retrieval proxy: <https://r.jina.ai/https://fccid.io/m/23de7d00a8b67c921eb44b2cc2b712d662633abb2997076e431e92e09d42ff61.pdf>.
- **S8 — Jim Fisher, PCMag, “YI M1 Review,” 2016-12-02:** <https://www.pcmag.com/reviews/yi-m1>. Hands-on Connectivity section confirms Wi-Fi join and contemporary JPG limitation. Retrieval proxy: <https://r.jina.ai/https://www.pcmag.com/reviews/yi-m1>.
- **S9 — Mike Tomkins, Imaging Resource, “YI M1 Review,” 2017 field tests/conclusion:** <https://www.imaging-resource.com/PRODS/yi-m1/yi-m1A.HTM>. Direct fetch worked; fixed screen/no viewfinder, early firmware behavior. Historical observations only.
- **S10 — Manufacturer Chinese downloads:** <https://www.xiaoyi.com/weidan_download.html>. Lists V3.2-cn, 2018-09-05; distinct from English V3.0-int listing.
