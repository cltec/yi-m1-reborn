// Running-app visual fixture. No camera, keyring or host network access.
import 'dart:async';
import 'package:yi_m1_reborn/application/diagnostics.dart';
import 'package:yi_m1_reborn/adapters/console_log.dart';
import 'package:flutter/material.dart';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/application/camera_network.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import 'package:yi_m1_reborn/application/pair_camera.dart';
import 'package:yi_m1_reborn/presentation/gallery.dart';
import 'network_fixture.dart';
import 'pairing_fixture.dart';

void main() {
  FlutterError.onError = (details) => consoleLog(
    LogEvent(
      LogLevel.error,
      'app.unexpected',
      code: details.exception.runtimeType.toString(),
      stackTrace: details.stack,
    ),
  );
  runApp(
    GalleryApp(
      discovery: _Discovery(),
      pairing: PairCamera(
        pairing: PreviewPairing(),
        store: PreviewStore()..camera = previewRemembered,
        network: _Network(),
        reachability: _Response(),
      ),
    ),
  );
}

class _Discovery implements CameraDiscovery {
  @override
  Future<List<DiscoveredCamera>> discover() async => [];
}

class _Network implements CameraNetwork {
  @override
  Future<CameraNetworkSession> join(
    CameraWifiCredentials credentials,
    PairingAttempt attempt,
  ) async {
    final session = SampleNetworkSession();
    const state = String.fromEnvironment('PREVIEW_STATE');
    if (state == 'lost') {
      Timer(const Duration(seconds: 2), () {
        if (!session.lostConnection.isCompleted)
          session.lostConnection.complete();
      });
      Timer(const Duration(seconds: 45), () {
        if (!session.disconnected.isCompleted) session.disconnected.complete();
      });
    }
    return session;
  }
}

class _Response implements CameraReachability {
  @override
  Future<void> verify(String address, PairingAttempt attempt) async {
    const state = String.fromEnvironment(
      'PREVIEW_STATE',
      defaultValue: 'connected',
    );
    if (state == 'unexpected')
      throw StateError('Simulated implementation fault');
    if (state == 'progress') await attempt.wait(Completer<void>().future);
    if (state == 'error')
      throw const PairingFailure('Camera response check failed. Select Retry.');
  }
}
