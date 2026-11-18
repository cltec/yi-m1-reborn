import 'dart:async';
import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:dbus/dbus.dart';

import '../../application/camera_discovery.dart';
import '../../application/camera_pairing.dart';
import '../../application/diagnostics.dart';

class BluezCameraDiscovery implements CameraDiscovery {
  /// [createClient] must return a fresh, owned client for each attempt.
  /// [scanDuration] is the collection window within [operationLimit], which also
  /// covers D-Bus setup. Cleanup always runs, with at most one second per step.
  BluezCameraDiscovery({
    BlueZClient Function()? createClient,
    this.log = const AppLog(),
    this.scanDuration = const Duration(seconds: 10),
    this.operationLimit = const Duration(seconds: 120),
  }) : _createClient = createClient ?? BlueZClient.new;

  static const _cameraService = '41106dd9-25ad-477b-a884-5038b6de4649';

  final BlueZClient Function() _createClient;
  final AppLog log;
  final Duration scanDuration;
  final Duration operationLimit;

  @override
  Future<List<DiscoveredCamera>> discover() async {
    final clock = Stopwatch()..start();
    final attempt = PairingAttempt(limit: operationLimit);
    var stage = 'opening_bluetooth';
    void event(LogLevel level, String name, {String? code, StackTrace? stack}) {
      log.emit(
        level,
        'ble.discovery.$name',
        stage: stage,
        elapsed: clock.elapsed,
        code: code,
        stackTrace: stack,
      );
    }

    void next(String value) {
      stage = value;
      event(LogLevel.info, 'stage');
    }

    BlueZClient? client;
    BlueZAdapter? adapter;
    var started = false;
    var failed = false;
    final cameras = <DiscoveredCamera>[];
    event(LogLevel.info, 'started');
    try {
      attempt.check();
      client = _createClient();
      attempt.check();
      await attempt.wait(client.connect());
      next('selecting_adapter');
      final poweredAdapters = client.adapters.where(
        (adapter) => adapter.powered,
      );
      log.emit(
        LogLevel.debug,
        'ble.discovery.adapters',
        stage: stage,
        elapsed: clock.elapsed,
        state: poweredAdapters.length,
      );
      if (poweredAdapters.isEmpty) {
        throw const DiscoveryFailure(
          'No powered Bluetooth adapter is available. Turn on Bluetooth and try again.',
        );
      }
      adapter = poweredAdapters.first;
      next('setting_filter');
      attempt.check();
      await attempt.wait(
        adapter.setDiscoveryFilter(uuids: [_cameraService], transport: 'le'),
      );
      next('starting_scan');
      attempt.check();
      await attempt.wait(adapter.startDiscovery());
      started = true;
      next('scanning');
      attempt.check();
      await attempt.wait(Future<void>.delayed(scanDuration));
      next('collecting_results');
      final service = BlueZUUID.fromString(_cameraService);
      for (final device in client.devices) {
        if (device.adapter.address == adapter.address &&
            device.uuids.contains(service)) {
          cameras.add(
            DiscoveredCamera(
              id: device.path.value,
              name: 'YI M1 ${cameras.length + 1}',
            ),
          );
        }
      }
      log.emit(
        LogLevel.debug,
        'ble.discovery.results',
        stage: stage,
        elapsed: clock.elapsed,
        state: cameras.length,
      );
    } catch (error, stack) {
      failed = true;
      final code = _failureCode(error);
      event(LogLevel.error, 'failed', code: code ?? 'unexpected', stack: stack);
      if (error is DiscoveryFailure || code == null) rethrow;
      Error.throwWithStackTrace(
        const DiscoveryFailure(
          'Camera discovery failed. Check Bluetooth permissions and try again.',
        ),
        stack,
      );
    } finally {
      attempt.cancel();
      (Object, StackTrace)? cleanupFailure;
      Future<void> release(
        String cleanupStage,
        Future<void> Function() action,
      ) async {
        stage = cleanupStage;
        try {
          await action().timeout(const Duration(seconds: 1));
          event(LogLevel.debug, 'cleanup.succeeded');
        } catch (error, stack) {
          final code = _failureCode(error);
          event(
            code == null ? LogLevel.error : LogLevel.warning,
            'cleanup.failed',
            code: code ?? 'unexpected',
            stack: stack,
          );
          cleanupFailure ??= (error, stack);
        }
      }

      if (started) await release('stopping_scan', adapter!.stopDiscovery);
      if (client != null) await release('closing_client', client.close);
      if (!failed && cleanupFailure != null) {
        final (error, stack) = cleanupFailure!;
        event(
          LogLevel.error,
          'failed',
          code: _failureCode(error) ?? 'unexpected',
          stack: stack,
        );
        if (_failureCode(error) == null)
          Error.throwWithStackTrace(error, stack);
        Error.throwWithStackTrace(
          const DiscoveryFailure(
            'Camera discovery failed. Check Bluetooth permissions and try again.',
          ),
          stack,
        );
      }
    }
    event(LogLevel.info, 'succeeded');
    return cameras;
  }
}

String? _failureCode(Object error) => switch (error) {
  DiscoveryFailure() => 'adapter_unavailable',
  PairingFailure() => 'attempt_ended',
  TimeoutException() => 'timeout',
  SocketException() => 'socket_failed',
  DBusClosedException() => 'bus_closed',
  BlueZInvalidArgumentsException() || DBusInvalidArgsException() => null,
  BlueZNotAuthorizedException() ||
  BlueZNotPermittedException() ||
  DBusAccessDeniedException() ||
  DBusAuthFailedException() => 'permission_denied',
  DBusMethodResponseException() => 'dbus_method_failed',
  _ => null,
};
