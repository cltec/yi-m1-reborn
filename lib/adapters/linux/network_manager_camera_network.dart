import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';

import '../../application/camera_network.dart';
import '../../application/camera_pairing.dart';
import '../../application/diagnostics.dart';

const _nm = 'org.freedesktop.NetworkManager';
const _managerPath = '/org/freedesktop/NetworkManager';

class NetworkManagerCameraNetwork implements CameraNetwork {
  /// Each join owns a fresh client, including clients returned by this factory.
  NetworkManagerCameraNetwork({
    DBusClient Function()? createClient,
    AppLog log = const AppLog(),
  }) : _createClient = createClient ?? DBusClient.system,
       _log = log;

  final DBusClient Function() _createClient;
  final AppLog _log;

  @override
  Future<CameraNetworkSession> join(
    CameraWifiCredentials credentials,
    PairingAttempt attempt,
  ) async {
    attempt.check();
    final clock = Stopwatch()..start();
    var stage = 'radio';
    _log.emit(
      LogLevel.info,
      'network.join.started',
      stage: stage,
      elapsed: clock.elapsed,
    );
    final session = _NetworkSession(_createClient(), _log);
    try {
      final enabled = await attempt.wait(
        session.manager.getProperty(_nm, 'WirelessEnabled'),
      );
      if (!enabled.asBoolean())
        throw const _NetworkFailure('wireless_disabled');
      stage = 'devices';
      _log.emit(
        LogLevel.info,
        'network.join.stage',
        stage: stage,
        elapsed: clock.elapsed,
      );
      final devices = await attempt.wait(
        session.manager.callMethod(
          _nm,
          'GetDevices',
          [],
          replySignature: DBusSignature('ao'),
        ),
      );
      DBusObjectPath? device;
      for (final path in devices.returnValues.single.asObjectPathArray()) {
        final properties = await attempt.wait(
          session.object(path).getAllProperties('$_nm.Device'),
        );
        _log.emit(
          LogLevel.info,
          'network.state',
          stage: 'device',
          elapsed: clock.elapsed,
          state: properties['State']?.asUint32(),
          reason: properties['StateReason']?.asStruct()[1].asUint32(),
        );
        if (properties['DeviceType']?.asUint32() == 2 &&
            properties['Managed']?.asBoolean() == true &&
            (properties['State']?.asUint32() ?? 0) >= 30) {
          device = path;
          break;
        }
      }
      if (device == null) throw const _NetworkFailure('no_usable_device');
      attempt.check();
      stage = 'activate';
      _log.emit(
        LogLevel.info,
        'network.join.stage',
        stage: stage,
        elapsed: clock.elapsed,
      );
      session.pendingActivation = session.manager
          .callMethod(
            _nm,
            'AddAndActivateConnection2',
            [
              _settings(credentials),
              device,
              DBusObjectPath('/'),
              DBusDict.stringVariant({
                'persist': const DBusString('volatile'),
                'bind-activation': const DBusString('dbus-name'),
              }),
            ],
            replySignature: DBusSignature('ooa{sv}'),
            allowInteractiveAuthorization: true,
          )
          .then((activation) {
            session.profile = activation.returnValues[0].asObjectPath();
            session.active = activation.returnValues[1].asObjectPath();
          });
      await attempt.wait(session.pendingActivation!);
      stage = 'address';
      _log.emit(
        LogLevel.info,
        'network.join.stage',
        stage: stage,
        elapsed: clock.elapsed,
      );
      final active = session.object(session.active!);
      session.stateSubscription =
          DBusRemoteObjectSignalStream(
            object: active,
            interface: '$_nm.Connection.Active',
            name: 'StateChanged',
            signature: DBusSignature('uu'),
          ).listen(
            (signal) {
              _log.emit(
                LogLevel.info,
                'network.state',
                stage: 'active',
                elapsed: clock.elapsed,
                state: signal.values[0].asUint32(),
                reason: signal.values[1].asUint32(),
              );
            },
            onError: (Object error, StackTrace stack) =>
                unawaited(session.observationFailed(error, stack)),
          );
      session.subscription = active.propertiesChanged.listen(
        (signal) {
          try {
            session.changed();
            if (signal.propertiesInterface != '$_nm.Connection.Active') return;
            if ((signal.changedProperties['State']?.asUint32() ?? 0) >= 3) {
              unawaited(session.close());
            } else if (signal.invalidatedProperties.contains('State')) {
              unawaited(session.checkActiveState());
            }
          } catch (error, stack) {
            unawaited(session.observationFailed(error, stack));
          }
        },
        onError: (Object error, StackTrace stack) =>
            unawaited(session.observationFailed(error, stack)),
      );
      Map<String, DBusValue> properties;
      while (true) {
        if (session.isClosing) throw const _NetworkFailure('session_ended');
        final changed = session.nextChange();
        properties = await attempt.wait(
          active.getAllProperties('$_nm.Connection.Active'),
        );
        final state = properties['State']!.asUint32();
        _log.emit(
          LogLevel.info,
          'network.state',
          stage: 'active',
          elapsed: clock.elapsed,
          state: state,
        );
        if (state >= 3) throw const _NetworkFailure('activation_ended');
        final ip4Path = properties['Ip4Config']!.asObjectPath();
        if (state == 2 && ip4Path.value != '/') {
          await session.watchIp4(ip4Path);
          final data = await attempt.wait(
            session
                .object(ip4Path)
                .getProperty('$_nm.IP4Config', 'AddressData'),
          );
          for (final row in (data as DBusArray).children) {
            final value = row.asStringVariantDict()['address']?.asString();
            final address = value == null
                ? null
                : InternetAddress.tryParse(value);
            if (address?.type == InternetAddressType.IPv4 &&
                address!.address != '0.0.0.0') {
              attempt.check();
              if (!session.isActive)
                throw const _NetworkFailure('session_ended');
              session.localAddress = address.address;
              _log.emit(
                LogLevel.info,
                'network.join.succeeded',
                stage: stage,
                elapsed: clock.elapsed,
              );
              return session;
            }
          }
        }
        await attempt.wait(changed);
      }
    } catch (error, stack) {
      _log.emit(
        LogLevel.error,
        'network.join.failed',
        stage: stage,
        elapsed: clock.elapsed,
        code: _errorCode(error),
        stackTrace: stack,
      );
      try {
        await session.close();
      } catch (_) {
        // _close reports each failure. Preserve the original join error here.
      }
      if (!_isManaged(error)) rethrow;
      throw const PairingFailure(
        'Camera Wi-Fi connection failed. Select Retry.',
      );
    }
  }
}

DBusValue _settings(CameraWifiCredentials credentials) {
  final settings = <String, Map<String, DBusValue>>{
    'connection': {
      'id': const DBusString('YI M1 temporary connection'),
      'type': const DBusString('802-11-wireless'),
      'autoconnect': const DBusBoolean(false),
    },
    '802-11-wireless': {
      'ssid': DBusArray.byte(utf8.encode(credentials.ssid)),
      'mode': const DBusString('infrastructure'),
    },
    '802-11-wireless-security': {
      'key-mgmt': const DBusString('wpa-psk'),
      'psk': DBusString(credentials.password),
      'psk-flags': const DBusUint32(2),
    },
    'ipv4': {
      'method': const DBusString('auto'),
      'never-default': const DBusBoolean(true),
      'ignore-auto-dns': const DBusBoolean(true),
    },
    'ipv6': {'method': const DBusString('disabled')},
  };
  return DBusDict(
    DBusSignature('s'),
    DBusSignature('a{sv}'),
    settings.map(
      (key, value) => MapEntry(DBusString(key), DBusDict.stringVariant(value)),
    ),
  );
}

class _NetworkSession implements CameraNetworkSession {
  _NetworkSession(this.client, this.log) {
    ownerSubscription = client.nameOwnerChanged.listen((event) {
      if (event.name == _nm && event.oldOwner != null) {
        serviceGone = true;
        log.emit(
          LogLevel.warning,
          'network.service.lost',
          stage: 'observe',
          elapsed: clock.elapsed,
          code: 'service_owner_changed',
        );
        changed();
        unawaited(close());
      }
    });
  }
  final DBusClient client;
  final AppLog log;
  final clock = Stopwatch()..start();
  bool serviceGone = false;
  StreamSubscription<DBusNameOwnerChangedEvent>? ownerSubscription;
  late final manager = object(DBusObjectPath(_managerPath));
  DBusObjectPath? profile;
  DBusObjectPath? active;
  Future<void>? pendingActivation;
  @override
  late String localAddress;
  final _lost = Completer<void>();
  final _ended = Completer<void>();
  @override
  bool get isActive => !_lost.isCompleted;
  @override
  Future<void> get lost => _lost.future;
  Future<void>? _closing;
  bool get isClosing => _closing != null;
  StreamSubscription<DBusPropertiesChangedSignal>? subscription;
  StreamSubscription<DBusSignal>? stateSubscription;
  StreamSubscription<DBusPropertiesChangedSignal>? ipSubscription;
  DBusObjectPath? _ipPath;
  Future<void> observationFailed(Object error, StackTrace stack) async {
    final managed = _isManaged(error);
    log.emit(
      managed ? LogLevel.warning : LogLevel.error,
      'network.observation.failed',
      stage: 'observe',
      elapsed: clock.elapsed,
      code: _errorCode(error),
      stackTrace: stack,
    );
    changed();
    try {
      await close();
    } catch (_) {
      // Cleanup reports its failures; preserve the observation failure.
    }
    if (!managed) Error.throwWithStackTrace(error, stack);
  }

  Future<void> checkActiveState() async {
    if (isClosing) return;
    try {
      final state = await object(
        active!,
      ).getProperty('$_nm.Connection.Active', 'State');
      final value = state.asUint32();
      log.emit(
        LogLevel.info,
        'network.state',
        stage: 'active',
        elapsed: clock.elapsed,
        state: value,
      );
      if (value >= 3) await close();
    } catch (error, stack) {
      await observationFailed(error, stack);
    }
  }

  Future<void> watchIp4(DBusObjectPath path) async {
    if (_ipPath == path) return;
    await ipSubscription?.cancel();
    _ipPath = path;
    ipSubscription = object(path).propertiesChanged.listen(
      (_) => changed(),
      onError: (Object error, StackTrace stack) =>
          unawaited(observationFailed(error, stack)),
    );
  }

  Completer<void>? _change;
  Future<void> nextChange() => (_change = Completer<void>()).future;
  void changed() {
    if (_change?.isCompleted == false) _change!.complete();
  }

  @override
  Future<void> get ended => _ended.future;
  DBusRemoteObject object(DBusObjectPath path) =>
      DBusRemoteObject(client, name: _nm, path: path);
  @override
  Future<void> close() {
    if (!_lost.isCompleted) _lost.complete();
    changed();
    return _closing ??= _close();
  }

  Future<void> _close() async {
    log.emit(LogLevel.info, 'network.cleanup.started', elapsed: clock.elapsed);
    Object? firstError;
    StackTrace? firstStack;
    Future<void> release(
      String stage,
      Future<dynamic> Function() operation, {
      bool bounded = false,
    }) async {
      try {
        await _release(stage, operation, bounded: bounded);
      } catch (error, stack) {
        // _release reports unexpected errors; continue cleanup, then rethrow.
        firstError ??= error;
        firstStack ??= stack;
      }
    }

    await release('cancel_active_watch', () async => subscription?.cancel());
    await release(
      'cancel_state_watch',
      () async => stateSubscription?.cancel(),
    );
    await release('cancel_ip_watch', () async => ipSubscription?.cancel());
    await release(
      'cancel_owner_watch',
      () async => ownerSubscription?.cancel(),
    );
    if (pendingActivation != null) {
      await release(
        'settle_activation',
        () => pendingActivation!,
        bounded: true,
      );
    }
    if (active != null && !serviceGone) {
      await release(
        'deactivate',
        () => manager.callMethod(_nm, 'DeactivateConnection', [
          active!,
        ], replySignature: DBusSignature('')),
        bounded: true,
      );
    }
    if (profile != null && !serviceGone) {
      await release(
        'delete_profile',
        () => object(profile!).callMethod(
          '$_nm.Settings.Connection',
          'Delete',
          [],
          replySignature: DBusSignature(''),
        ),
        bounded: true,
      );
    }
    await release('close', client.close);
    if (!_ended.isCompleted) _ended.complete();
    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
    log.emit(
      LogLevel.info,
      'network.cleanup.completed',
      elapsed: clock.elapsed,
    );
  }

  Future<void> _release(
    String stage,
    Future<dynamic> Function() operation, {
    required bool bounded,
  }) async {
    try {
      final pending = operation();
      await (bounded ? pending.timeout(const Duration(seconds: 1)) : pending);
    } catch (error, stack) {
      final managed = _isManaged(error);
      log.emit(
        managed ? LogLevel.warning : LogLevel.error,
        'network.cleanup.failed',
        stage: stage,
        elapsed: clock.elapsed,
        code: _errorCode(error),
        stackTrace: stack,
      );
      if (!managed) rethrow;
    }
  }
}

class _NetworkFailure implements Exception {
  const _NetworkFailure(this.code);
  final String code;
}

bool _isManaged(Object error) =>
    error is! DBusInvalidArgsException &&
    (error is _NetworkFailure ||
        error is PairingFailure ||
        error is DBusMethodResponseException ||
        error is DBusClosedException ||
        // Signature errors describe a remote response/contract mismatch, not a cast
        // or assumption error in our own code. Report the mismatch without payloads.
        error is DBusReplySignatureException ||
        error is DBusPropertySignatureException ||
        error is DBusSignalSignatureException ||
        error is SocketException ||
        error is TimeoutException);

String _errorCode(Object error) {
  if (error is _NetworkFailure) return error.code;
  if (error is PairingFailure) return 'attempt_ended';
  if (error is DBusMethodResponseException) {
    // Only stable protocol names are safe; arbitrary remote names may carry data.
    const names = {
      'org.freedesktop.DBus.Error.AccessDenied',
      'org.freedesktop.DBus.Error.AuthFailed',
      'org.freedesktop.DBus.Error.Failed',
      'org.freedesktop.DBus.Error.NoReply',
      'org.freedesktop.DBus.Error.ServiceUnknown',
      'org.freedesktop.DBus.Error.UnknownObject',
      'org.freedesktop.DBus.Error.UnknownInterface',
      'org.freedesktop.DBus.Error.UnknownMethod',
      'org.freedesktop.DBus.Error.UnknownProperty',
      'org.freedesktop.DBus.Error.InvalidArgs',
      'org.freedesktop.DBus.Error.NotSupported',
      'org.freedesktop.DBus.Error.Timeout',
      'org.freedesktop.DBus.Error.TimedOut',
      'org.freedesktop.NetworkManager.PermissionDenied',
      'org.freedesktop.NetworkManager.UnknownConnection',
      'org.freedesktop.NetworkManager.ConnectionNotActive',
      'org.freedesktop.NetworkManager.DependencyFailed',
      'org.freedesktop.NetworkManager.AlreadyAsleepOrAwake',
      'org.freedesktop.NetworkManager.InvalidArguments',
      'org.freedesktop.NetworkManager.MissingPlugin',
      'org.freedesktop.NetworkManager.Failed',
      'org.freedesktop.NetworkManager.Settings.PermissionDenied',
      'org.freedesktop.NetworkManager.Settings.InvalidConnection',
      'org.freedesktop.NetworkManager.Device.NotAvailable',
      'org.freedesktop.NetworkManager.Device.NotActive',
    };
    return names.contains(error.errorName)
        ? error.errorName
        : 'dbus.remote_error';
  }
  return error.runtimeType.toString();
}
