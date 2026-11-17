# Platform feasibility: Android, iPhone and web

Research date: 2026-11-16. This is a feasibility assessment, not an application specification or a tested implementation.

## Summary

A Flutter **native Android and iOS** application is a reasonable candidate, subject to recovering the camera protocol. A Flutter **web build is not automatically an equivalent camera client**. Flutter can share UI and protocol code, but it cannot remove browser or operating-system restrictions.

No plugin, minimum OS version, package license or application architecture has been selected. No camera connection has been tested.

## Native mobile applications

| Area | Android | iOS |
| --- | --- | --- |
| Bluetooth | Native BLE APIs exist. Android 12+ distinguishes runtime scan/connect permissions. The exact camera service and commands remain to be established. [P3] | Core Bluetooth provides native Bluetooth APIs. Camera-specific compatibility still needs a device test. [P4] |
| Joining the camera Wi-Fi | The Wi-Fi Network Request API supports user-approved connections to accessory networks on Android 10+. Nearby Wi-Fi permissions apply to relevant APIs on Android 13+. [P5, P6] | `NEHotspotConfigurationManager` supports user-approved Wi-Fi configuration, with the Hotspot Configuration capability. Manual joining in Settings is also an option to investigate. [P7] |
| Local network | Networking must use the camera-connected network even if it has no Internet. OS-version-specific permission and routing behavior must be tested. | Local network access is subject to a separate user permission. Apple documents the behavior and failure cases. [P8] |
| Legacy unencrypted camera service | If the recovered API uses HTTP, Android network-security settings need review; do not disable transport security globally as a shortcut. [P9] | If HTTP is needed, review App Transport Security and narrowly scoped local-network configuration. This remains a conditional requirement, not a recovered camera fact. [P12] |
| Downloading photos | Native file/media storage APIs can support this, but original JPEG/RAW support, metadata and save destinations are still product decisions. | Native file/photo-library APIs can support this, with the required permissions depending on save destination. |

Bluetooth discovery and Wi-Fi transfer should be treated as separate questions. The camera's Bluetooth support does **not** by itself prove that it sends full-resolution images over Bluetooth.

## Web limitations

1. **Bluetooth is not universally available.** Web Bluetooth exposes BLE/GATT to supported browsers, generally in a secure context and after a user action. Safari/iOS does not provide native Web Bluetooth support in the compatibility data checked. A third-party extension is not equivalent to built-in browser support. [P1, P2, P10]
2. **Wi-Fi cannot be assumed to switch automatically.** A normal website does not have the native hotspot-configuration APIs used by Android/iOS apps. The user may need to join the camera network in system settings.
3. **The recovered transport matters.** If the camera requires an arbitrary raw TCP or UDP connection, ordinary browser networking cannot directly reproduce a native socket client. Flutter web does not provide `dart:io` networking. HTTP or WebSocket support on the camera must be demonstrated, not assumed. [P11]
4. **HTTP access still has browser rules.** Cross-origin access may require headers the old camera does not send. Loading an image for display does not imply JavaScript can read, process or download its bytes. CORS is controlled by the camera server, not fixed by adding a client request header or using `no-cors`. [P13]
5. **Local-network restrictions are changing.** Chrome documents a Local Network Access permission launching in Chrome 142. Its documented private-address HTTP exemptions mean it is too broad to claim that HTTPS-to-camera HTTP is always blocked. Permission, CORS, transport and browser compatibility still require individual testing. [P14]
6. **Offline startup matters.** A camera access point may lack Internet. A browser app would need to be loaded or cached before switching networks; this would not solve missing Bluetooth or socket APIs.

A web gallery for already imported pictures may be possible without direct camera access. A local companion/proxy could make some browser workflows possible, but it adds another component and is not being proposed as an agreed requirement.

## What must be established before promising compatibility

Source-level answers for many items below are now available in [original app analysis](original-app-analysis.md) and [protocol prior art](protocol-prior-art.md). These are the remaining **target-device validation** needs, not a claim that the protocol is still unknown:

- Actual advertised Bluetooth services, characteristic permissions and accepted write modes on this body/firmware.
- Pairing/session behavior and whether stored credentials can be reused reliably.
- User-approved joining of the camera Wi-Fi with credentials obtained through BLE, including manual joining where needed.
- Camera addressing and routing on the intended phone/OS versions.
- File listing, thumbnails and original-file operations, with JPEG/RAW/video differences recorded separately.
- End-to-end operation without vendor login, cloud services or Internet access.
- Actual tests on the user's firmware and target Android/iPhone versions.

## Sources

All URLs below were fetched successfully on 2026-11-16. Apple Markdown versions were used where the HTML page only supplied a JavaScript shell.

- **P1:** Chrome, Communicating with Bluetooth devices over JavaScript: https://developer.chrome.com/docs/capabilities/bluetooth
- **P2:** MDN, Web Bluetooth API: https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API
- **P3:** Android, Bluetooth permissions: https://developer.android.com/develop/connectivity/bluetooth/bt-permissions
- **P4:** Apple, Core Bluetooth: https://developer.apple.com/documentation/corebluetooth.md
- **P5:** Android, Wi-Fi Network Request API: https://developer.android.com/develop/connectivity/wifi/wifi-bootstrap
- **P6:** Android, Nearby Wi-Fi permissions: https://developer.android.com/develop/connectivity/wifi/wifi-permissions
- **P7:** Apple, NEHotspotConfigurationManager: https://developer.apple.com/documentation/networkextension/nehotspotconfigurationmanager.md
- **P8:** Apple, Understanding local network privacy: https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy.md
- **P9:** Android, Network security configuration: https://developer.android.com/privacy-and-security/security-config
- **P10:** Can I use, Web Bluetooth compatibility: https://caniuse.com/web-bluetooth
- **P11:** Flutter, Web FAQ: https://docs.flutter.dev/platform-integration/web/faq
- **P12:** Apple, NSAllowsLocalNetworking: https://developer.apple.com/documentation/bundleresources/information-property-list/nsapptransportsecurity/nsallowslocalnetworking.md
- **P13:** MDN, Cross-Origin Resource Sharing: https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS
- **P14:** Chrome, New permission prompt for Local Network Access: https://developer.chrome.com/blog/local-network-access
