import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/adapters/linux/network_manager_camera_network.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import 'package:yi_m1_reborn/application/diagnostics.dart';

const _nm = 'org.freedesktop.NetworkManager';
const _managerPath = '/org/freedesktop/NetworkManager';
const _devicePath = '$_managerPath/Devices/1';
const _profilePath = '$_managerPath/Settings/8';
const _activePath = '$_managerPath/ActiveConnection/8';
const _ipPath = '$_managerPath/IP4Config/8';

void main() {
  late DBusServer server;
  late DBusClient service;
  late DBusAddress address;
  late _Manager manager;
  late _Device device;
  late _Active active;
  late _Profile profile;
  late List<_OwnedClient> clients;

  setUp(() async {
    server = DBusServer();
    address = await server.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    service = DBusClient(address);
    await service.requestName(_nm);
    manager = _Manager();
    device = _Device();
    active = _Active();
    profile = _Profile();
    for (final object in <DBusObject>[
      manager,
      device,
      active,
      profile,
      _Ip4(),
    ]) {
      await service.registerObject(object);
    }
    clients = [];
  });

  tearDown(() async {
    for (final client in clients) {
      await client.close();
    }
    await service.close();
    await server.close();
  });

  NetworkManagerCameraNetwork network({
    AppLog log = const AppLog(),
    Object? closeFailure,
  }) => NetworkManagerCameraNetwork(
    log: log,
    createClient: () {
      final client = _OwnedClient(address)..closeFailure = closeFailure;
      clients.add(client);
      return client;
    },
  );

  test(
    'Given camera credentials, join supplies a private volatile profile and returns its IPv4 address',
    () async {
      const credentials = CameraWifiCredentials(
        ssid: 'YI é',
        password: 'sample-secret',
      );

      final attempt = PairingAttempt();
      final session = await network().join(credentials, attempt);
      attempt.cancel(); // The established session outlives the join attempt.

      expect(session.localAddress, '192.168.42.2');
      expect(clients.single.closed, isFalse);
      expect(manager.options, {
        'persist': const DBusString('volatile'),
        'bind-activation': const DBusString('dbus-name'),
      });
      expect(manager.device, DBusObjectPath(_devicePath));
      expect(manager.specificObject, DBusObjectPath('/'));
      final settings = manager.settings;
      expect(
        settings['connection']!['type'],
        const DBusString('802-11-wireless'),
      );
      expect(settings['connection']!['autoconnect'], const DBusBoolean(false));
      expect(
        settings['802-11-wireless']!['ssid']!.asByteArray(),
        utf8.encode(credentials.ssid),
      );
      expect(
        settings['802-11-wireless']!['mode'],
        const DBusString('infrastructure'),
      );
      expect(
        settings['802-11-wireless-security']!['key-mgmt'],
        const DBusString('wpa-psk'),
      );
      expect(
        settings['802-11-wireless-security']!['psk'],
        const DBusString('sample-secret'),
      );
      expect(
        settings['802-11-wireless-security']!['psk-flags'],
        const DBusUint32(2),
      );
      expect(settings['ipv4']!['method'], const DBusString('auto'));
      expect(settings['ipv4']!['never-default'], const DBusBoolean(true));
      expect(settings['ipv4']!['ignore-auto-dns'], const DBusBoolean(true));
      expect(settings['ipv6']!['method'], const DBusString('disabled'));
      await session.close();
    },
  );

  test(
    'Given unavailable devices, join selects an available managed Wi-Fi device without changing power or profiles',
    () async {
      device.state = 20;
      final wired = _Device(path: '$_managerPath/Devices/wired', type: 1);
      final unmanaged = _Device(
        path: '$_managerPath/Devices/unmanaged',
        managed: false,
      );
      final available = _Device(path: '$_managerPath/Devices/available');
      for (final candidate in [wired, unmanaged, available]) {
        await service.registerObject(candidate);
        manager.devices.add(candidate.path);
      }

      final session = await network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        PairingAttempt(),
      );

      expect(manager.device, available.path);
      expect(
        [device, wired, unmanaged, available].expand((d) => d.writes),
        isEmpty,
      );
      await session.close();
    },
  );

  test(
    'Given activation in progress, join waits for activated state before returning',
    () async {
      active.state = 1;
      var joined = false;
      final pending = network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        PairingAttempt(),
      );
      unawaited(
        pending.then((_) {
          joined = true;
        }, onError: (Object _) {}),
      );
      await active.read.future;
      expect(joined, isFalse);

      active.state = 2;
      await active.emitPropertiesChanged(
        '$_nm.Connection.Active',
        changedProperties: {'State': const DBusUint32(2)},
      );
      final session = await pending;

      expect(session.localAddress, '192.168.42.2');
      await session.close();
    },
  );

  test(
    'Given activated state without IPv4 configuration, join waits for the local address',
    () async {
      active.ip4 = '/';
      final pending = network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        PairingAttempt(),
      );
      await active.read.future;

      active.ip4 = _ipPath;
      await active.emitPropertiesChanged(
        '$_nm.Connection.Active',
        changedProperties: {'Ip4Config': DBusObjectPath(_ipPath)},
      );
      final session = await pending;

      expect(session.localAddress, '192.168.42.2');
      await session.close();
    },
  );

  test(
    'Given an ended activation, ended completes only after temporary profile cleanup',
    () async {
      final session = await network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        PairingAttempt(),
      );
      expect(session.isActive, isTrue);
      profile.deleteGate = Completer<void>();
      var ended = false;
      unawaited(
        session.ended.then((_) {
          ended = true;
        }),
      );

      active.state = 4;
      await active.emitPropertiesChanged(
        '$_nm.Connection.Active',
        changedProperties: {'State': const DBusUint32(4)},
      );
      await session.lost.timeout(const Duration(seconds: 2));
      expect(session.isActive, isFalse);
      await profile.deleteRequested.future.timeout(const Duration(seconds: 2));
      expect(ended, isFalse);
      profile.deleteGate!.complete();
      await session.ended.timeout(const Duration(seconds: 2));

      expect(profile.deletions, 1);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given cancellation while activation returns late, join settles after removing its late profile',
    () async {
      manager.addGate = Completer<void>();
      final attempt = PairingAttempt();
      var settled = false;
      final pending = network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        attempt,
      );
      final failure = expectLater(pending, throwsA(isA<PairingFailure>()));
      unawaited(
        pending.then(
          (_) {
            settled = true;
          },
          onError: (Object _) {
            settled = true;
          },
        ),
      );
      await manager.addRequested.future;

      attempt.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      manager.addGate!.complete();
      await failure;

      expect(manager.deactivated, [DBusObjectPath(_activePath)]);
      expect(profile.deletions, 1);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given NetworkManager rejects activation, join redacts private errors and releases its client',
    () async {
      manager.failAdd = true;
      final events = <LogEvent>[];

      await expectLater(
        network(log: AppLog(sink: events.add)).join(
          const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
          PairingAttempt(),
        ),
        throwsA(
          isA<PairingFailure>().having(
            (e) => e.message,
            'message',
            allOf(contains('Wi-Fi'), isNot(contains('private'))),
          ),
        ),
      );

      final failure = events.singleWhere(
        (event) => event.event == 'network.join.failed',
      );
      expect(failure.level, LogLevel.error);
      expect(failure.stage, 'activate');
      expect(failure.code, '$_nm.PermissionDenied');
      expect(failure.elapsed, isNotNull);
      expect(failure.stackTrace, isNotNull);
      expect(events.first.event, 'network.join.started');
      final diagnosticText = events
          .map(
            (event) => [
              event.event,
              event.stage,
              event.code,
              event.state,
              event.reason,
              event.stackTrace,
            ].join(' '),
          )
          .join('\n');
      expect(diagnosticText, isNot(contains('private password or identifier')));
      expect(diagnosticText, isNot(contains('secret')));
      expect(profile.deletions, 0);
      expect(manager.deactivated, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given invalid D-Bus call arguments, join fails fast after cleanup instead of offering normal Retry',
    () async {
      manager.failAdd = true;
      manager.addErrorName = 'org.freedesktop.DBus.Error.InvalidArgs';
      final events = <LogEvent>[];
      await expectLater(
        network(log: AppLog(sink: events.add)).join(
          const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
          PairingAttempt(),
        ),
        throwsA(isA<DBusInvalidArgsException>()),
      );
      expect(clients.single.closed, isTrue);
      final failure = events.singleWhere(
        (event) => event.event == 'network.join.failed',
      );
      expect(failure.level, LogLevel.error);
      expect(failure.code, 'org.freedesktop.DBus.Error.InvalidArgs');
      expect(failure.stackTrace, isNotNull);
    },
  );

  test(
    'Given an unrecognized remote error name, diagnostics redact its contents',
    () async {
      manager.failAdd = true;
      manager.addErrorName = '$_nm.private_ssid_secret_identifier';
      final events = <LogEvent>[];
      await expectLater(
        network(log: AppLog(sink: events.add)).join(
          const CameraWifiCredentials(
            ssid: 'private-ssid',
            password: 'private-password',
          ),
          PairingAttempt(),
        ),
        throwsA(isA<PairingFailure>()),
      );
      expect(
        events
            .singleWhere((event) => event.event == 'network.join.failed')
            .code,
        'dbus.remote_error',
      );
      final text = events
          .map(
            (event) => [
              event.event,
              event.stage,
              event.code,
              event.state,
              event.reason,
              event.stackTrace,
            ].join(' '),
          )
          .join('\n');
      for (final private in [
        'private',
        'secret',
        'identifier',
        _activePath,
        _profilePath,
        _devicePath,
      ]) {
        expect(text, isNot(contains(private)));
      }
    },
  );

  test(
    'Given an unexpected StateError during activation setup, join rethrows the same error after releasing its client',
    () async {
      final error = StateError('private implementation detail');
      final events = <LogEvent>[];
      await expectLater(
        network(
          log: AppLog(sink: events.add),
        ).join(_BrokenCredentials(error), PairingAttempt()),
        throwsA(same(error)),
      );
      expect(clients.single.closed, isTrue);
      expect(
        events
            .singleWhere((event) => event.event == 'network.join.failed')
            .code,
        'StateError',
      );
    },
  );

  test(
    'Given malformed platform property types, join preserves the TypeError and releases its client',
    () async {
      manager.wirelessValue = const DBusString('private payload');
      final events = <LogEvent>[];
      await expectLater(
        network(log: AppLog(sink: events.add)).join(
          const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
          PairingAttempt(),
        ),
        throwsA(isA<TypeError>()),
      );
      expect(clients.single.closed, isTrue);
      expect(
        events
            .singleWhere((event) => event.event == 'network.join.failed')
            .code,
        contains('TypeError'),
      );
    },
  );

  test(
    'Given an unexpected join error and cleanup error, the original error survives and cleanup is reported',
    () async {
      manager.wirelessValue = const DBusString('private payload');
      final events = <LogEvent>[];
      await expectLater(
        network(
          log: AppLog(sink: events.add),
          closeFailure: StateError('private cleanup'),
        ).join(
          const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
          PairingAttempt(),
        ),
        throwsA(isA<TypeError>()),
      );
      expect(clients.single.closed, isTrue);
      final cleanup = events.singleWhere(
        (event) => event.event == 'network.cleanup.failed',
      );
      expect(cleanup.level, LogLevel.error);
      expect(cleanup.code, 'StateError');
      expect(cleanup.stackTrace, isNotNull);
    },
  );

  test(
    'Given managed cleanup failures, cleanup warns and continues releasing owned resources',
    () async {
      manager.failDeactivate = true;
      profile.failDelete = true;
      final events = <LogEvent>[];
      final session = await network(log: AppLog(sink: events.add)).join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        PairingAttempt(),
      );
      await session.close();
      await session.ended;
      final warnings = events
          .where((event) => event.event == 'network.cleanup.failed')
          .toList();
      expect(warnings.map((event) => event.stage), [
        'deactivate',
        'delete_profile',
      ]);
      expect(
        warnings.every((event) => event.level == LogLevel.warning),
        isTrue,
      );
      expect(
        warnings.every(
          (event) => event.elapsed != null && event.stackTrace != null,
        ),
        isTrue,
      );
      expect(clients.single.closed, isTrue);
      expect(profile.deletions, 1);
    },
  );

  test(
    'Given NetworkManager state changes, diagnostics retain only numeric state and reason codes',
    () async {
      final events = <LogEvent>[];
      final session = await network(log: AppLog(sink: events.add)).join(
        const CameraWifiCredentials(
          ssid: 'private-ssid',
          password: 'private-password',
        ),
        PairingAttempt(),
      );
      await active.emitSignal('$_nm.Connection.Active', 'StateChanged', [
        const DBusUint32(4),
        const DBusUint32(6),
      ]);
      active.state = 4;
      await active.emitPropertiesChanged(
        '$_nm.Connection.Active',
        changedProperties: {'State': const DBusUint32(4)},
      );
      await session.ended.timeout(const Duration(seconds: 2));
      expect(
        events.any(
          (event) =>
              event.event == 'network.state' &&
              event.state == 4 &&
              event.reason == 6 &&
              event.elapsed != null,
        ),
        isTrue,
      );
      expect(
        events.any((event) => event.event == 'network.join.succeeded'),
        isTrue,
      );
      expect(
        events.any((event) => event.event == 'network.cleanup.completed'),
        isTrue,
      );
    },
  );

  for (final invalidated in [true, false]) {
    test(
      'Given an unexpected state ${invalidated ? "read" : "signal"} error, cleanup runs and the original error reaches error reporting',
      () async {
        final errors = Completer<Object>();
        final settled = Completer<void>();
        final events = <LogEvent>[];
        unawaited(
          runZonedGuarded(
            () async {
              final session = await network(log: AppLog(sink: events.add)).join(
                const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
                PairingAttempt(),
              );
              active.stateValue = const DBusString('private invalid state');
              await active.emitPropertiesChanged(
                '$_nm.Connection.Active',
                invalidatedProperties: invalidated ? ['State'] : [],
                changedProperties: invalidated
                    ? {}
                    : {'State': active.stateValue!},
              );
              await session.ended;
              settled.complete();
            },
            (error, stack) {
              if (!errors.isCompleted) errors.complete(error);
            },
          ),
        );
        await settled.future.timeout(const Duration(seconds: 2));
        expect(
          await errors.future.timeout(const Duration(seconds: 2)),
          isA<TypeError>(),
        );
        expect(clients.single.closed, isTrue);
        expect(
          events
              .singleWhere(
                (event) => event.event == 'network.observation.failed',
              )
              .level,
          LogLevel.error,
        );
      },
    );
  }

  test(
    'Given cancellation while waiting, join cleans its temporary profile without retry',
    () async {
      active.state = 1;
      final attempt = PairingAttempt();
      final pending = network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        attempt,
      );
      final failure = expectLater(pending, throwsA(isA<PairingFailure>()));
      await active.read.future;
      attempt.cancel();
      await failure;

      expect(
        manager.calls.where((c) => c == 'AddAndActivateConnection2'),
        hasLength(1),
      );
      expect(manager.deactivated, [DBusObjectPath(_activePath)]);
      expect(profile.deletions, 1);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given disabled Wi-Fi, join fails without enabling radio or creating a profile',
    () async {
      manager.wirelessEnabled = false;

      await expectLater(
        network().join(
          const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
          PairingAttempt(),
        ),
        throwsA(isA<PairingFailure>()),
      );

      expect(manager.calls, isNot(contains('AddAndActivateConnection2')));
      expect(manager.writes, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given an activation call that never replies, the shared deadline releases the owned D-Bus client',
    () async {
      manager.addGate = Completer<void>();
      final pending = network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        PairingAttempt(limit: const Duration(milliseconds: 50)),
      );

      await expectLater(
        pending.timeout(const Duration(seconds: 2)),
        throwsA(isA<PairingFailure>()),
      );

      expect(clients.single.closed, isTrue);
      expect(manager.options['bind-activation'], const DBusString('dbus-name'));
      manager.addGate!.complete();
    },
  );

  test(
    'Given NetworkManager disappears, the session ends and releases its client',
    () async {
      final session = await network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        PairingAttempt(),
      );

      await service.releaseName(_nm);
      await session.lost.timeout(const Duration(seconds: 2));
      expect(session.isActive, isFalse);
      await session.ended.timeout(const Duration(seconds: 2));

      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given an invalidated active state, the session reads it and cleans up on link loss',
    () async {
      final session = await network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        PairingAttempt(),
      );
      active.state = 4;

      await active.emitPropertiesChanged(
        '$_nm.Connection.Active',
        invalidatedProperties: ['State'],
      );
      await session.ended.timeout(const Duration(seconds: 2));

      expect(profile.deletions, 1);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given failed activation state, join removes the temporary network without retry',
    () async {
      active.state = 4;
      await expectLater(
        network().join(
          const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
          PairingAttempt(),
        ),
        throwsA(isA<PairingFailure>()),
      );
      expect(
        manager.calls.where((c) => c == 'AddAndActivateConnection2'),
        hasLength(1),
      );
      expect(profile.deletions, 1);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given no usable Wi-Fi device, join fails without creating a profile or changing policy',
    () async {
      device.state = 20;
      await expectLater(
        network().join(
          const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
          PairingAttempt(),
        ),
        throwsA(isA<PairingFailure>()),
      );
      expect(manager.calls, isNot(contains('AddAndActivateConnection2')));
      expect(device.writes, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given an owned network session, close removes only its active connection and profile before ended',
    () async {
      final unrelated = _Profile(path: '$_managerPath/Settings/other');
      await service.registerObject(unrelated);
      final session = await network().join(
        const CameraWifiCredentials(ssid: 'YI', password: 'secret'),
        PairingAttempt(),
      );
      var ended = false;
      unawaited(
        session.ended.then((_) {
          ended = true;
        }),
      );

      final closing = session.close();
      expect(session.isActive, isFalse);
      await session.lost;
      await closing;
      await session.ended;
      await session.close();

      expect(ended, isTrue);
      expect(manager.deactivated, [DBusObjectPath(_activePath)]);
      expect(profile.deletions, 1);
      expect(unrelated.deletions, 0);
      expect(clients.single.closed, isTrue);
    },
  );
}

class _BrokenCredentials extends CameraWifiCredentials {
  _BrokenCredentials(this.error) : super(ssid: 'unused', password: 'unused');
  final StateError error;
  @override
  String get ssid => throw error;
}

class _OwnedClient extends DBusClient {
  _OwnedClient(super.address);
  bool closed = false;
  Object? closeFailure;
  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    await super.close();
    if (closeFailure case final error?) throw error;
  }
}

class _Manager extends _PropertiesObject {
  _Manager() : super(DBusObjectPath(_managerPath));
  Map<String, Map<String, DBusValue>> settings = {};
  Map<String, DBusValue> options = {};
  DBusObjectPath? device;
  DBusObjectPath? specificObject;
  final calls = <String>[];
  final deactivated = <DBusObjectPath>[];
  final devices = [DBusObjectPath(_devicePath)];
  Completer<void>? addGate;
  bool failAdd = false;
  String addErrorName = '$_nm.PermissionDenied';
  bool failDeactivate = false;
  bool wirelessEnabled = true;
  DBusValue? wirelessValue;
  final addRequested = Completer<void>();
  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    _nm: {'WirelessEnabled': wirelessValue ?? DBusBoolean(wirelessEnabled)},
  };
  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    calls.add(call.name);
    switch (call.name) {
      case 'GetDevices':
        return DBusMethodSuccessResponse([DBusArray.objectPath(devices)]);
      case 'AddAndActivateConnection2':
        if (failAdd)
          return DBusMethodErrorResponse(addErrorName, [
            const DBusString('private password or identifier'),
          ]);
        settings = (call.values[0] as DBusDict).children.map(
          (key, value) => MapEntry(key.asString(), value.asStringVariantDict()),
        );
        device = call.values[1].asObjectPath();
        specificObject = call.values[2].asObjectPath();
        options = call.values[3].asStringVariantDict();
        if (!addRequested.isCompleted) addRequested.complete();
        await addGate?.future;
        return DBusMethodSuccessResponse([
          DBusObjectPath(_profilePath),
          DBusObjectPath(_activePath),
          DBusDict.stringVariant({}),
        ]);
      case 'DeactivateConnection':
        deactivated.add(call.values.single.asObjectPath());
        if (failDeactivate)
          return DBusMethodErrorResponse('$_nm.ConnectionNotActive', [
            const DBusString('private cleanup'),
          ]);
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }
}

class _Device extends _PropertiesObject {
  _Device({String path = _devicePath, this.type = 2, this.managed = true})
    : super(DBusObjectPath(path));
  final int type;
  final bool managed;
  int state = 30;
  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    '$_nm.Device': {
      'DeviceType': DBusUint32(type),
      'Managed': DBusBoolean(managed),
      'State': DBusUint32(state),
    },
  };
}

class _Active extends _PropertiesObject {
  _Active() : super(DBusObjectPath(_activePath));
  int state = 2;
  DBusValue? stateValue;
  String ip4 = _ipPath;
  final read = Completer<void>();
  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    if (!read.isCompleted) read.complete();
    return super.getAllProperties(interface);
  }

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    '$_nm.Connection.Active': {
      'State': stateValue ?? DBusUint32(state),
      'Ip4Config': DBusObjectPath(ip4),
    },
  };
}

class _Ip4 extends _PropertiesObject {
  _Ip4() : super(DBusObjectPath(_ipPath));
  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    '$_nm.IP4Config': {
      'AddressData': DBusArray(DBusSignature('a{sv}'), [
        DBusDict.stringVariant({
          'address': const DBusString('192.168.42.2'),
          'prefix': const DBusUint32(24),
        }),
      ]),
    },
  };
}

class _Profile extends _PropertiesObject {
  _Profile({String path = _profilePath}) : super(DBusObjectPath(path));
  int deletions = 0;
  bool failDelete = false;
  Completer<void>? deleteGate;
  final deleteRequested = Completer<void>();
  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.name != 'Delete') return DBusMethodErrorResponse.unknownMethod();
    deletions++;
    if (!deleteRequested.isCompleted) deleteRequested.complete();
    await deleteGate?.future;
    if (failDelete)
      return DBusMethodErrorResponse.unknownObject('private profile');
    return DBusMethodSuccessResponse();
  }
}

class _PropertiesObject extends DBusObject {
  _PropertiesObject(super.path);
  final writes = <String>[];
  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    writes.add('$interface.$name');
    return DBusMethodErrorResponse.propertyReadOnly();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(interfacesAndProperties[interface] ?? {});
  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = interfacesAndProperties[interface]?[name];
    return value == null
        ? DBusMethodErrorResponse.unknownProperty()
        : DBusGetPropertyResponse(value);
  }
}
