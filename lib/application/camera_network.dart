import 'camera_pairing.dart';

/// An owned temporary camera-network connection. Closing it must never remove
/// or modify a pre-existing user network profile.
abstract interface class CameraNetworkSession {
  String get localAddress;
  bool get isActive;
  Future<void> get lost;

  /// Completes only after owned connection/profile cleanup settles.
  Future<void> get ended;
  Future<void> close();
}

abstract interface class CameraNetwork {
  Future<CameraNetworkSession> join(
    CameraWifiCredentials credentials,
    PairingAttempt attempt,
  );
}

abstract interface class CameraReachability {
  Future<void> verify(String localAddress, PairingAttempt attempt);
}
