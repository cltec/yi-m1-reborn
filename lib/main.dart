import 'dart:ui';
import 'package:flutter/material.dart';
import 'application/diagnostics.dart';
import 'adapters/console_log.dart';
import 'adapters/linux/bluez_camera_discovery.dart';
import 'adapters/linux/network_manager_camera_network.dart';
import 'adapters/camera_http_reachability.dart';
import 'adapters/linux/bluez_camera_pairing.dart';
import 'adapters/linux/keyring_pairing_store.dart';
import 'application/discovery_approval.dart';
import 'application/pair_camera.dart';
import 'presentation/gallery.dart';

void main() {
  const debugLogs = bool.fromEnvironment('CAMERA_DEBUG_LOGS');
  const log = AppLog(
    sink: consoleLog,
    minimumLevel: debugLogs ? LogLevel.debug : LogLevel.info,
  );
  FlutterError.onError = (details) {
    log.emit(
      LogLevel.error,
      'app.unexpected',
      code: details.exception.runtimeType.toString(),
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.emit(
      LogLevel.error,
      'app.unexpected',
      code: error.runtimeType.toString(),
      stackTrace: stack,
    );
    return true; // Reported safely; do not let runtime fallback print raw payloads.
  };
  log.emit(LogLevel.info, 'app.started');
  const discoveryApproved = bool.fromEnvironment('CAMERA_DISCOVERY_APPROVED');
  const pairingApproved = bool.fromEnvironment('CAMERA_PAIRING_APPROVED');
  const networkApproved = bool.fromEnvironment('CAMERA_NETWORK_APPROVED');
  runApp(
    GalleryApp(
      discovery: discoveryApproved
          ? BluezCameraDiscovery(log: log)
          : DiscoveryApprovalRequired(),
      pairing: discoveryApproved && pairingApproved
          ? PairCamera(
              log: log,
              pairing: BluezCameraPairing(
                activateWifi: networkApproved,
                log: log,
              ),
              store: KeyringPairingStore(log: log),
              network: networkApproved
                  ? NetworkManagerCameraNetwork(log: log)
                  : null,
              reachability: networkApproved
                  ? CameraHttpReachability(log: log)
                  : null,
            )
          : null,
    ),
  );
}
