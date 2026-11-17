# Future device validation

Historical broad research checklist from 2026-11-16. For issue #1, use the approved dependency order and scoped procedure in the [current validation handoff](../development/validation-handoff.md). Mobile, preview and download checks below are not part of that first-slice plan.

Status: **proposed follow-up only**. None of these steps was performed. This is not a requirement to change settings now, nor a complete app specification.

## Information needed first

1. Camera body firmware version and region (for example, international versus Chinese). A photo or transcription of the version screen is enough; omit serial numbers.
2. Android/iPhone models and OS versions that should be supported.
3. Whether the old app is still installed anywhere, and whether the camera remembers an old pairing.
4. Whether the camera records JPEG, DNG/RAW or RAW+JPEG. Desired download formats can be discussed later.

## Safety boundaries

- Back up the SD card first and use a few expendable test images for initial checks.
- Keep the camera charged and record its starting settings.
- Obtain explicit approval before pairing: sources report that a new pairing replaces the stored old pairing.
- Do not factory-reset, update/downgrade firmware, unpair another device, delete files, upload files or change camera settings as part of an automatic diagnostic.
- Do not use malformed paths, traversal payloads, fuzzing or undocumented firmware commands. The gallery workflow does not need them.
- Do not publish BLE pairing tokens, Wi-Fi passwords, personal photos, card identifiers or serial numbers in logs.

## Proposed checks in order

| Check | Evidence to collect | Pass condition |
| --- | --- | --- |
| Passive discovery | Advertisement/service identifiers and body version | Identifies the actual M1 without borrowing constants from YI Home/action cameras |
| GATT inspection | Readable UUIDs and write/notify properties | Required characteristics are present; optional ones are not assumed |
| Authorized pairing | User accepts on camera; sanitized result and write mode recorded | Non-empty pairing result and successful session; no unexplained repeated attempts |
| Wi-Fi setup | Credentials read privately; user-approved join; active interface/route | Phone reaches the camera network despite its lack of Internet |
| Harmless HTTP query | Actual HTTP status and JSON status recorded separately | A camera query returns the expected structure without changing settings |
| File listing | Small requests; record indexing/page behavior | Paths and media types agree with known files on the test card |
| Preview | Request a JPEG thumbnail without original fallback | Correct image; unsupported RAW thumbnail does not trigger an unwanted large download |
| Selected original download | Save one JPEG unchanged; compare size and SHA-256 against the SD-card copy | Exact file match, not a recompressed preview |
| DNG / RAW+JPEG, if wanted | Repeat original-file comparison and check pair membership | Originals preserved; no unsupported RAW preview promise |
| Disconnect and reconnect | Power cycle/link loss, remembered pairing, user cancellation | Clear recovery without replacing pairing or changing settings unexpectedly |
| Platform checks | Repeat on intended Android and iPhone versions | Permissions, routing and local save behavior work on each actual device |

Use the smallest proven command set. Do not start UDP live view just to browse photos unless device testing establishes that the camera requires that state. Download scheduling should follow measured camera behavior rather than assuming concurrent HTTP requests are safe.

## Questions these checks must resolve

- Community clients disagree on `GetFileList` indexing and page sizes. Which requests work on this body/firmware?
- Which BLE write type is accepted on each phone platform?
- Does entering remote-control/album mode affect local camera operation or photo access?
- Can pairing/session credentials be reused without another camera-screen confirmation?
- Which preview sizes exist for JPEG, DNG, video and RAW+JPEG entries?
- Can gallery/download operations stay fully offline, without the original app or vendor login?
- How should partial downloads, link loss and low battery be reported without leaving a corrupt file in the phone gallery?

A successful read-only proof of connection and exact original-file download would support the later app-design discussion. It would not by itself prove a production-ready app or browser compatibility.
