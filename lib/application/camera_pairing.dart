import 'dart:async';

import 'camera_discovery.dart';

class RememberedCamera {
  const RememberedCamera({
    required this.address,
    required this.addressType,
    required this.protocol,
    required this.referenceId,
    required this.token,
  });

  final String address;
  final String addressType;
  final int protocol;
  final String referenceId;
  final String token;
}

class CameraWifiCredentials {
  const CameraWifiCredentials({required this.ssid, required this.password});
  final String ssid;
  final String password;
}

class PairingFailure implements Exception {
  const PairingFailure(this.message);
  final String message;
}

class PairingStorageFailure implements Exception {
  const PairingStorageFailure();
}

/// One budget covers pairing, storage and session setup. A timed-out operation
/// must check this before any subsequent side effect; Future.timeout alone
/// does not cancel underlying platform work.
class PairingAttempt {
  PairingAttempt({this.limit = const Duration(seconds: 120)});

  final Duration limit;
  final Stopwatch _clock = Stopwatch()..start();
  final Completer<void> _cancellation = Completer<void>();

  Duration get remaining => limit - _clock.elapsed;

  void cancel() {
    if (!_cancellation.isCompleted) _cancellation.complete();
  }

  void check() {
    if (_cancellation.isCompleted || remaining <= Duration.zero) {
      throw const PairingFailure(
        'Camera connection attempt ended. Select Retry.',
      );
    }
  }

  Future<T> wait<T>(Future<T> operation) async {
    check();
    try {
      final result = await Future.any<T>([
        operation,
        _cancellation.future.then<T>(
          (_) => throw const PairingFailure(
            'Camera connection attempt ended. Select Retry.',
          ),
        ),
      ]).timeout(remaining);
      check();
      return result;
    } on TimeoutException {
      cancel();
      throw const PairingFailure('Camera connection timed out. Select Retry.');
    }
  }
}

/// Implementations must honor the attempt before further camera effects and
/// finish owned-resource cleanup before returning. Platform cleanup may be
/// bounded/best effort: a timed-out D-Bus reply does not cancel daemon work.
/// Callers must await this settlement rather than race it with an outer timeout.
abstract interface class CameraPairing {
  Future<RememberedCamera> pair(
    DiscoveredCamera camera,
    PairingAttempt attempt,
  );
  Future<CameraWifiCredentials> resume(
    RememberedCamera camera,
    PairingAttempt attempt,
  );
}

abstract interface class PairingStore {
  Future<RememberedCamera?> read();
  Future<void> save(RememberedCamera camera);
}
