import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:dbus/dbus.dart';

import '../../application/camera_discovery.dart';
import '../../application/camera_pairing.dart';
import '../../application/diagnostics.dart';

class BluezCameraPairing implements CameraPairing {
  /// Each call owns a fresh client; the factory must not share clients.
  BluezCameraPairing({
    BlueZClient Function()? createClient,
    this.log = const AppLog(),
    int Function()? generateReferenceId,
    this.rediscoveryWindow = const Duration(seconds: 10),
    this.activateWifi = false,
  }) : _createClient = createClient ?? BlueZClient.new,
       _generateReferenceId =
           generateReferenceId ?? (() => Random.secure().nextInt(99999));

  static const _serviceUuid = '41106dd9-25ad-477b-a884-5038b6de4649';
  final BlueZClient Function() _createClient;
  final AppLog log;
  final int Function() _generateReferenceId;
  final Duration rediscoveryWindow;
  final bool activateWifi;

  @override
  Future<RememberedCamera> pair(
    DiscoveredCamera camera,
    PairingAttempt attempt,
  ) async {
    final session = _GattSession(attempt, log, 'pair');
    var requested = false;
    late RememberedCamera result;
    try {
      final device = await _connect(
        session,
        (client) => client.devices.where(
          (device) => device.path.value == camera.id && _isM1(device),
        ),
      );
      session.stage = 'checking pairing characteristics';
      final chars = _characteristics(device);
      final firmware = _require(chars, 'a2', BlueZGattCharacteristicFlag.read);
      final initiate = _requireWrite(chars, 'a0');
      final response = _require(
        chars,
        'a7',
        BlueZGattCharacteristicFlag.notify,
      );
      _requireWrite(chars, 'a4');
      _require(chars, 'a6', BlueZGattCharacteristicFlag.read);
      if (activateWifi) _requireWrite(chars, 'a5');
      session.stage = 'reading camera firmware';
      attempt.check();
      final fields = _ascii(
        await attempt.wait(firmware.readValue()),
      ).split(',');
      if (fields.length < 2 || fields.first != '1' || fields[1].isEmpty) {
        throw const _ProtocolFailure();
      }
      final reference = _generateReferenceId();
      if (reference < 0 || reference >= 99999)
        throw StateError('Invalid generated reference');
      final tokenBytes = Completer<List<int>?>();
      var notificationFailed = false;
      (Object, StackTrace)? notificationError;
      void checkNotificationError() {
        final failure = notificationError;
        if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
      }

      session.stage = 'subscribing for camera approval';
      attempt.check();
      void notificationEnded() {
        notificationFailed = true;
        if (!tokenBytes.isCompleted) tokenBytes.complete(null);
      }

      session.subscription = response.propertiesChanged.listen(
        (properties) {
          if (requested &&
              properties.contains('Value') &&
              !tokenBytes.isCompleted) {
            tokenBytes.complete(response.value);
          }
        },
        onError: (Object error, StackTrace stack) {
          notificationError = (error, stack);
          notificationEnded();
        },
        onDone: notificationEnded,
      );
      attempt.check();
      session.notification = response;
      await attempt.wait(response.startNotify());
      session.stage = 'requesting camera approval';
      attempt.check();
      checkNotificationError();
      if (notificationFailed) throw const _ProtocolFailure();
      requested = true;
      await attempt.wait(
        initiate.writeValue(
          ascii.encode('1,$reference,android'),
          type: _writeType(initiate),
        ),
      );
      session.stage = 'waiting for camera approval';
      final bytes = await attempt.wait(tokenBytes.future);
      checkNotificationError();
      if (bytes == null) throw const _ProtocolFailure();
      final token = _ascii(bytes);
      if (token.isEmpty) throw const _Refused();
      if (!_validToken(token)) {
        throw const _ProtocolFailure();
      }
      result = RememberedCamera(
        address: device.address,
        addressType: device.addressType.name,
        protocol: 1,
        referenceId: reference.toString(),
        token: token,
      );
    } catch (error, stack) {
      session.failed(error, stack);
      if (_failureCode(error) == null) rethrow;
      Error.throwWithStackTrace(
        PairingFailure(
          error is _Refused
              ? 'Camera declined pairing. New pairing requires approval.'
              : 'Camera pairing failed while ${session.stage}.'
                    '${requested ? ' Pairing outcome may be unknown; do not pair again without approval.' : ' Select Retry.'}',
        ),
        stack,
      );
    } finally {
      await session.close();
    }
    session.event(LogLevel.info, 'succeeded');
    return result;
  }

  @override
  Future<CameraWifiCredentials> resume(
    RememberedCamera camera,
    PairingAttempt attempt,
  ) async {
    final session = _GattSession(attempt, log, 'resume');
    late CameraWifiCredentials result;
    try {
      session.stage = 'checking remembered pairing';
      if (camera.protocol != 1 ||
          !RegExp(r'^(0|[1-9][0-9]{0,4})$').hasMatch(camera.referenceId) ||
          int.parse(camera.referenceId) >= 99999 ||
          !_validToken(camera.token)) {
        throw const _ProtocolFailure();
      }
      final device = await _connect(
        session,
        (client) => client.devices.where(
          (device) =>
              device.address == camera.address &&
              device.addressType.name == camera.addressType,
        ),
        rediscoverIfMissing: true,
      );
      session.stage = 'checking session characteristics';
      final chars = _characteristics(device);
      final initiate = _requireWrite(chars, 'a4');
      final credentials = _require(
        chars,
        'a6',
        BlueZGattCharacteristicFlag.read,
      );
      final wifiSwitch = activateWifi ? _requireWrite(chars, 'a5') : null;
      session.stage = 'starting the remembered camera session';
      attempt.check();
      final checksum = _crc32(
        ascii.encode('1${camera.referenceId}${camera.token}'),
      );
      await attempt.wait(
        initiate.writeValue(
          ascii.encode('1,${camera.referenceId},$checksum'),
          type: _writeType(initiate),
        ),
      );
      // The original app reads da6 directly after da4. Optional ad/ae/af
      // state notifications are not needed to request fresh credentials.
      session.stage = 'reading camera Wi-Fi credentials';
      attempt.check();
      final fields = _ascii(
        await attempt.wait(credentials.readValue()),
      ).split(',');
      if (fields.length != 2 ||
          fields.any(
            (field) =>
                field.isEmpty ||
                field.codeUnits.any((byte) => byte < 32 || byte > 126),
          )) {
        throw const _ProtocolFailure();
      }
      if (wifiSwitch != null) {
        session.stage = 'enabling camera Wi-Fi';
        attempt.check();
        await attempt.wait(
          wifiSwitch.writeValue(
            ascii.encode('ON'),
            type: _writeType(wifiSwitch),
          ),
        );
      }
      result = CameraWifiCredentials(ssid: fields[0], password: fields[1]);
    } catch (error, stack) {
      session.failed(error, stack);
      if (_failureCode(error) == null) rethrow;
      Error.throwWithStackTrace(
        PairingFailure(
          'Camera session failed while ${session.stage}. Select Retry to reuse the remembered pairing.',
        ),
        stack,
      );
    } finally {
      await session.close();
    }
    session.event(LogLevel.info, 'succeeded');
    return result;
  }

  bool _validToken(String token) =>
      token.isNotEmpty &&
      token.codeUnits.every((byte) => byte >= 33 && byte <= 126 && byte != 44);

  int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc ^= byte;
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc >>> 1) ^ ((crc & 1) == 1 ? 0xedb88320 : 0);
      }
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }

  bool _isM1(BlueZDevice device) =>
      device.uuids.contains(BlueZUUID.fromString(_serviceUuid));

  Future<BlueZDevice> _connect(
    _GattSession session,
    Iterable<BlueZDevice> Function(BlueZClient) resolve, {
    bool rediscoverIfMissing = false,
  }) async {
    final attempt = session.attempt;
    session.stage = 'opening Bluetooth';
    attempt.check();
    final client = _createClient();
    session.client = client;
    attempt.check();
    await attempt.wait(client.connect());
    session.stage = 'finding the selected camera';
    var matches = resolve(client).toList();
    if (matches.isEmpty && rediscoverIfMissing) {
      session.stage = 'rediscovering the remembered camera';
      await _rediscover(client, resolve, session);
      session.stage = 'finding the remembered camera after discovery';
      matches = resolve(client).toList();
    }
    if (matches.length != 1) throw const _ProtocolFailure();
    final device = matches.single;
    if (device.address.isEmpty) throw const _ProtocolFailure();
    session.stage = 'checking for an existing Bluetooth connection';
    // BlueZ Disconnect is device-wide; never borrow somebody else's link.
    if (device.connected) throw const _ProtocolFailure();
    session.stage = 'connecting to camera Bluetooth';
    attempt.check();
    session.device = device;
    await attempt.wait(device.connect());
    session.stage = 'resolving camera services';
    final resolved = Completer<bool>();
    (Object, StackTrace)? resolutionError;
    void resolutionEnded() {
      if (!resolved.isCompleted) resolved.complete(false);
    }

    attempt.check();
    session.resolutionSubscription = device.propertiesChanged.listen(
      (_) {
        if (device.servicesResolved && !resolved.isCompleted)
          resolved.complete(true);
      },
      onError: (Object error, StackTrace stack) {
        resolutionError = (error, stack);
        resolutionEnded();
      },
      onDone: resolutionEnded,
    );
    if (device.servicesResolved && !resolved.isCompleted)
      resolved.complete(true);
    final servicesResolved = await attempt.wait(resolved.future);
    final failure = resolutionError;
    if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
    if (!servicesResolved) throw const _ProtocolFailure();
    session.log.emit(
      LogLevel.debug,
      'ble.${session.operation}.services',
      stage: session.stage,
      elapsed: session.clock.elapsed,
      state: 1,
    );
    return device;
  }

  Future<void> _rediscover(
    BlueZClient client,
    Iterable<BlueZDevice> Function(BlueZClient) resolve,
    _GattSession session,
  ) async {
    final attempt = session.attempt;
    final adapters = client.adapters.where((adapter) => adapter.powered);
    if (adapters.isEmpty) throw const _ProtocolFailure();
    final adapter = adapters.first;
    final found = Completer<(Object, StackTrace)?>();
    final subscription = client.deviceAdded.listen(
      (_) {
        if (resolve(client).length == 1 && !found.isCompleted) found.complete();
      },
      onError: (Object error, StackTrace stack) {
        if (!found.isCompleted) found.complete((error, stack));
      },
      onDone: () {
        if (!found.isCompleted)
          found.complete((const _ProtocolFailure(), StackTrace.current));
      },
    );
    var started = false;
    var failed = false;
    try {
      attempt.check();
      await attempt.wait(
        adapter.setDiscoveryFilter(uuids: [_serviceUuid], transport: 'le'),
      );
      attempt.check();
      await attempt.wait(adapter.startDiscovery());
      started = true;
      if (resolve(client).length == 1 && !found.isCompleted) found.complete();
      final failure = await attempt.wait(
        Future.any<(Object, StackTrace)?>([
          found.future,
          Future<(Object, StackTrace)?>.delayed(rediscoveryWindow, () => null),
        ]),
      );
      if (failure != null) Error.throwWithStackTrace(failure.$1, failure.$2);
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      (Object, StackTrace)? unexpected;
      Future<void> release(String step, Future<void> Function() action) async {
        try {
          await action().timeout(const Duration(seconds: 1));
          session.event(LogLevel.debug, 'cleanup.$step.succeeded');
        } catch (error, stack) {
          final code = _failureCode(error);
          session.event(
            code == null ? LogLevel.error : LogLevel.warning,
            'cleanup.$step.failed',
            code: code ?? 'unexpected',
            stack: stack,
          );
          if (code == null) unexpected ??= (error, stack);
        }
      }

      await release('rediscovery_subscription', subscription.cancel);
      if (started) await release('rediscovery_scan', adapter.stopDiscovery);
      if (!failed && unexpected != null) {
        Error.throwWithStackTrace(unexpected!.$1, unexpected!.$2);
      }
    }
    attempt.check();
  }

  Map<String, BlueZGattCharacteristic> _characteristics(BlueZDevice device) {
    final services = device.gattServices.where(
      (service) => service.uuid == BlueZUUID.fromString(_serviceUuid),
    );
    if (services.length != 1) throw const _ProtocolFailure();
    return {
      for (final characteristic in services.single.characteristics)
        characteristic.uuid.toString(): characteristic,
    };
  }

  BlueZGattCharacteristic _require(
    Map<String, BlueZGattCharacteristic> chars,
    String short,
    BlueZGattCharacteristicFlag flag,
  ) {
    final char = chars['41106d$short-25ad-477b-a884-5038b6de4649'];
    if (char == null || !char.flags.contains(flag))
      throw const _ProtocolFailure();
    return char;
  }

  BlueZGattCharacteristic _requireWrite(
    Map<String, BlueZGattCharacteristic> chars,
    String short,
  ) {
    final char = chars['41106d$short-25ad-477b-a884-5038b6de4649'];
    if (char == null) throw const _ProtocolFailure();
    _writeType(char);
    return char;
  }

  BlueZGattCharacteristicWriteType _writeType(BlueZGattCharacteristic char) {
    if (char.flags.contains(BlueZGattCharacteristicFlag.write))
      return BlueZGattCharacteristicWriteType.request;
    if (char.flags.contains(BlueZGattCharacteristicFlag.writeWithoutResponse))
      return BlueZGattCharacteristicWriteType.command;
    throw const _ProtocolFailure();
  }

  String _ascii(List<int> bytes) {
    var end = bytes.length;
    while (end > 0 && bytes[end - 1] == 0) {
      end--;
    }
    try {
      return ascii.decode(bytes.sublist(0, end));
    } on FormatException {
      throw const _ProtocolFailure();
    }
  }
}

class _Refused implements Exception {
  const _Refused();
}

class _ProtocolFailure implements Exception {
  const _ProtocolFailure();
}

String? _failureCode(Object error) => switch (error) {
  _ProtocolFailure() => 'protocol_invalid',
  _Refused() => 'pairing_refused',
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

class _GattSession {
  _GattSession(this.attempt, this.log, this.operation) {
    event(LogLevel.info, 'started');
  }
  final PairingAttempt attempt;
  final AppLog log;
  final String operation;
  final Stopwatch clock = Stopwatch()..start();
  String _stage = 'opening Bluetooth';
  bool hasFailure = false;
  String get stage => _stage;
  set stage(String value) {
    _stage = value;
    event(LogLevel.info, 'stage');
  }

  void event(LogLevel level, String name, {String? code, StackTrace? stack}) {
    log.emit(
      level,
      'ble.$operation.$name',
      stage: stage,
      elapsed: clock.elapsed,
      code: code,
      stackTrace: stack,
    );
  }

  void failed(Object error, StackTrace stack) {
    hasFailure = true;
    event(
      LogLevel.error,
      'failed',
      code: _failureCode(error) ?? 'unexpected',
      stack: stack,
    );
  }

  BlueZClient? client;
  BlueZDevice? device;
  BlueZGattCharacteristic? notification;
  StreamSubscription<List<String>>? subscription;
  StreamSubscription<List<String>>? resolutionSubscription;

  Future<void> close() async {
    // Cleanup runs after the connection budget expires and releases every owner.
    (Object, StackTrace)? unexpected;
    Future<void> release(String step, Future<void> Function() operation) async {
      try {
        await operation().timeout(const Duration(seconds: 1));
        event(LogLevel.debug, 'cleanup.$step.succeeded');
      } catch (error, stack) {
        final code = _failureCode(error);
        event(
          code == null ? LogLevel.error : LogLevel.warning,
          'cleanup.$step.failed',
          code: code ?? 'unexpected',
          stack: stack,
        );
        if (code == null) unexpected ??= (error, stack);
      }
    }

    if (resolutionSubscription != null)
      await release(
        'resolution_subscription',
        () => resolutionSubscription!.cancel(),
      );
    if (subscription != null)
      await release('approval_subscription', () => subscription!.cancel());
    if (notification != null)
      await release('notification', notification!.stopNotify);
    if (device != null) await release('device', device!.disconnect);
    if (client != null) await release('client', client!.close);
    if (!hasFailure && unexpected != null) {
      final (error, stack) = unexpected!;
      failed(error, stack);
      Error.throwWithStackTrace(error, stack);
    }
  }
}
