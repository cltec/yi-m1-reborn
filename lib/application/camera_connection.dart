import 'camera_discovery.dart';
import 'camera_network.dart';

enum PairingStage {
  storage,
  cameraApproval,
  saving,
  session,
  wifi,
  verification,
}

/// Gallery connection workflow, independent of BLE, networking and storage APIs.
abstract interface class CameraConnection {
  bool get includesNetwork;
  bool get connected;

  /// Available only after network and harmless response verification succeed.
  CameraNetworkSession? get verifiedSession;
  Future<void>? get connectionLost;
  Future<void>? get connectionEnded;
  Future<bool> resumeRemembered({void Function(PairingStage)? onProgress});
  Future<void> pair(
    DiscoveredCamera camera, {
    void Function(PairingStage)? onProgress,
  });
  Future<void> cancel();
}
