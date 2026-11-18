import 'dart:async';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';

const previewRemembered = RememberedCamera(
  address: 'simulated',
  addressType: 'public',
  protocol: 1,
  referenceId: '42',
  token: 'simulated',
);

class PreviewPairing implements CameraPairing {
  final approval = Completer<RememberedCamera>();
  int pairs = 0;
  @override
  Future<RememberedCamera> pair(
    DiscoveredCamera camera,
    PairingAttempt attempt,
  ) {
    pairs++;
    return approval.future;
  }

  @override
  Future<CameraWifiCredentials> resume(
    RememberedCamera camera,
    PairingAttempt attempt,
  ) async =>
      const CameraWifiCredentials(ssid: 'simulated', password: 'simulated');
}

class PreviewStore implements PairingStore {
  RememberedCamera? camera;
  @override
  Future<RememberedCamera?> read() async => camera;
  @override
  Future<void> save(RememberedCamera value) async {
    camera = value;
  }
}
