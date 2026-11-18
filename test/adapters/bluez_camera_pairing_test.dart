import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/adapters/linux/bluez_camera_pairing.dart';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import 'package:yi_m1_reborn/application/diagnostics.dart';

const serviceUuid = '41106dd9-25ad-477b-a884-5038b6de4649';
String characteristicUuid(String short) =>
    '41106d$short-25ad-477b-a884-5038b6de4649';

void main() {
  late DBusServer server;
  late DBusClient service;
  late DBusAddress address;
  late List<_OwnedClient> clients;
  late _Camera camera;

  setUp(() async {
    server = DBusServer();
    address = await server.listenAddress(
      DBusAddress.unix(dir: Directory.systemTemp),
    );
    service = DBusClient(address);
    await service.requestName('org.bluez');
    await service.registerObject(
      DBusObject(DBusObjectPath('/'), isObjectManager: true),
    );
    clients = [];
    camera = _Camera();
    await camera.register(service);
  });

  tearDown(() async {
    for (final client in clients) {
      await client.close();
    }
    await service.close();
    await server.close();
  });

  BluezCameraPairing pairing({
    AppLog log = const AppLog(),
    Stream<BlueZDevice>? deviceAdded,
  }) => BluezCameraPairing(
    log: log,
    createClient: () {
      final client = _OwnedClient(
        DBusClient(address),
        deviceAddedOverride: deviceAdded,
      );
      clients.add(client);
      return client;
    },
    generateReferenceId: () => 12345,
    rediscoveryWindow: const Duration(milliseconds: 50),
  );

  test(
    'Given an unexpected rediscovery stream error, Resume preserves it and stops scanning',
    () async {
      await service.unregisterObject(camera.device);
      final updates = StreamController<BlueZDevice>();
      final error = StateError('private stream detail');
      final scan = _Adapter()
        ..onStart = () async {
          updates.addError(error, StackTrace.current);
        };
      await service.registerObject(scan);

      try {
        await expectLater(
          pairing(
            deviceAdded: updates.stream,
          ).resume(_remembered(), PairingAttempt()),
          throwsA(same(error)),
        );
        expect(scan.calls.last, 'StopDiscovery');
        expect(clients.single.closed, isTrue);
      } finally {
        await updates.close();
      }
    },
  );

  test(
    'Given a generator format error, Pair preserves the programming failure and cleanup still runs',
    () async {
      final error = const FormatException('private generator detail');
      final adapter = BluezCameraPairing(
        createClient: () {
          final client = _OwnedClient(DBusClient(address));
          clients.add(client);
          return client;
        },
        generateReferenceId: () => throw error,
      );

      await expectLater(
        adapter.pair(camera.discovered, PairingAttempt()),
        throwsA(same(error)),
      );
      expect(camera.calls.last, 'Disconnect');
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given unexpected cleanup failure, Pair releases resources and preserves primary failure',
    () async {
      for (final failConnect in [false, true]) {
        final cleanupError = StateError('private cleanup detail');
        final primaryError = StateError('private connect detail');
        final events = <LogEvent>[];
        final adapter = BluezCameraPairing(
          log: AppLog(sink: events.add),
          createClient: () {
            final client = _OwnedClient(
              DBusClient(address),
              closeError: cleanupError,
              connectError: failConnect ? primaryError : null,
            );
            clients.add(client);
            return client;
          },
        );

        await expectLater(
          adapter.pair(camera.discovered, PairingAttempt()),
          throwsA(same(failConnect ? primaryError : cleanupError)),
        );
        expect(clients.last.closed, isTrue);
        expect(
          events
              .where((event) => event.event == 'ble.pair.cleanup.client.failed')
              .single
              .level,
          LogLevel.error,
        );
        expect(
          events.where((event) => event.event == 'ble.pair.succeeded'),
          isEmpty,
        );
      }
    },
  );

  test(
    'Given an unexpected service stream error, Pair preserves it and closes the client',
    () async {
      camera.device.resolveOnConnect = false;
      final error = StateError('private stream detail');
      final updates = StreamController<List<String>>();
      final adapter = BluezCameraPairing(
        createClient: () {
          final client = _OwnedClient(
            DBusClient(address),
            deviceProperties: updates.stream,
          );
          clients.add(client);
          return client;
        },
      );
      updates.onListen = () => updates.addError(error, StackTrace.current);

      try {
        await expectLater(
          adapter.pair(camera.discovered, PairingAttempt()),
          throwsA(same(error)),
        );
        expect(clients.single.closed, isTrue);
        expect(camera.calls, ['Connect', 'Disconnect']);
      } finally {
        await updates.close();
      }
    },
  );

  test(
    'Given approved pairing and reuse, diagnostics show safe lifecycle and state',
    () async {
      final events = <LogEvent>[];
      final adapter = pairing(
        log: AppLog(sink: events.add, minimumLevel: LogLevel.debug),
      );

      final remembered = await adapter.pair(
        camera.discovered,
        PairingAttempt(),
      );
      await adapter.resume(remembered, PairingAttempt());

      expect(events.first.event, 'ble.pair.started');
      expect(
        events
            .where((event) => event.event == 'ble.pair.succeeded')
            .single
            .level,
        LogLevel.info,
      );
      expect(events.last.event, 'ble.resume.succeeded');
      expect(
        events.where(
          (event) => event.stage == 'reading camera Wi-Fi credentials',
        ),
        isNotEmpty,
      );
      expect(
        events.where((event) => event.level == LogLevel.debug),
        isNotEmpty,
      );
      expect(events.every((event) => event.elapsed != null), isTrue);
      final text = events
          .map(
            (e) =>
                '${e.event} ${e.stage} ${e.code} ${e.state} ${e.reason} ${e.stackTrace}',
          )
          .join();
      for (final secret in [
        'accepted-token',
        '12345',
        'camera-network',
        'session-password',
        'AA:BB:CC:DD:EE:FF',
        'private',
        '/org/bluez',
      ]) {
        expect(text, isNot(contains(secret)));
      }
    },
  );

  test(
    'Given an unexpected factory error, Pair and Resume preserve it',
    () async {
      final error = StateError('private programming detail');
      final adapter = BluezCameraPairing(createClient: () => throw error);

      await expectLater(
        adapter.pair(camera.discovered, PairingAttempt()),
        throwsA(same(error)),
      );
      await expectLater(
        adapter.resume(_remembered(), PairingAttempt()),
        throwsA(same(error)),
      );
    },
  );

  test(
    'Given Wi-Fi activation enabled, Resume enables AP only after fresh credentials',
    () async {
      final adapter = BluezCameraPairing(
        createClient: () {
          final client = _OwnedClient(DBusClient(address));
          clients.add(client);
          return client;
        },
        activateWifi: true,
      );

      await adapter.resume(_remembered(), PairingAttempt());

      expect(camera.calls, [
        'Connect',
        'Write:a4',
        'Read:a6',
        'Write:a5',
        'Disconnect',
      ]);
      expect(camera.characteristics['a5']!.writes.single, ('ON', 'request'));
      expect(camera.characteristics['a0']!.writes, isEmpty);
    },
  );

  test(
    'Given no Wi-Fi switch capability, network-enabled Resume sends no session write',
    () async {
      camera.characteristics['a5']!.flags = [];
      final adapter = BluezCameraPairing(
        createClient: () {
          final client = _OwnedClient(DBusClient(address));
          clients.add(client);
          return client;
        },
        activateWifi: true,
      );
      await expectLater(
        adapter.resume(_remembered(), PairingAttempt()),
        throwsA(isA<PairingFailure>()),
      );
      expect(camera.calls, ['Connect', 'Disconnect']);
      expect(camera.characteristics['a0']!.writes, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given no Wi-Fi switch capability, network-enabled Pair never requests registration',
    () async {
      camera.characteristics['a5']!.flags = [];
      final adapter = BluezCameraPairing(
        createClient: () {
          final client = _OwnedClient(DBusClient(address));
          clients.add(client);
          return client;
        },
        activateWifi: true,
      );
      await expectLater(
        adapter.pair(camera.discovered, PairingAttempt()),
        throwsA(isA<PairingFailure>()),
      );
      expect(camera.calls, ['Connect', 'Disconnect']);
      expect(camera.characteristics['a0']!.writes, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given remembered approval, Resume uses a fresh session and reads fresh credentials without pairing',
    () async {
      final adapter = pairing();
      final remembered = await adapter.pair(
        camera.discovered,
        PairingAttempt(),
      );
      camera.calls.clear();
      final result = await adapter.resume(remembered, PairingAttempt());

      expect(result.ssid, 'camera-network');
      expect(result.password, 'session-password');
      expect(camera.calls, ['Connect', 'Write:a4', 'Read:a6', 'Disconnect']);
      expect(camera.characteristics['a4']!.writes.single, (
        '1,12345,4136317662',
        'request',
      ));
      expect(camera.characteristics['a0']!.writes, hasLength(1));
      expect(clients, hasLength(2));
      expect(clients.every((client) => client.closed), isTrue);
    },
  );

  test(
    'Given remembered identity without cached UUIDs, Resume verifies GATT before session setup',
    () async {
      camera.device.uuids = [];

      final credentials = await pairing().resume(
        _remembered(),
        PairingAttempt(),
      );

      expect(credentials.ssid, 'camera-network');
      expect(camera.calls, ['Connect', 'Write:a4', 'Read:a6', 'Disconnect']);
      expect(camera.characteristics['a0']!.writes, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given an absent remembered device, Resume rediscovers only that identity without pairing',
    () async {
      await service.unregisterObject(camera.device);
      final discovery = _Adapter();
      discovery.onStart = () async {
        await service.registerObject(_Device(camera.calls));
      };
      await service.registerObject(discovery);

      final credentials = await pairing().resume(
        _remembered(),
        PairingAttempt(),
      );

      expect(credentials.ssid, 'camera-network');
      expect(discovery.calls, [
        'SetDiscoveryFilter',
        'StartDiscovery',
        'StopDiscovery',
      ]);
      expect(discovery.filter['UUIDs']?.asStringArray(), [serviceUuid]);
      expect(discovery.filter['Transport']?.asString(), 'le');
      expect(camera.calls, ['Connect', 'Write:a4', 'Read:a6', 'Disconnect']);
      expect(camera.characteristics['a0']!.writes, isEmpty);
    },
  );

  test(
    'Given remembered identity on non-M1 GATT, Resume sends no session or pairing write',
    () async {
      camera.device.uuids = [];
      await service.unregisterObject(camera.gattService);
      await expectLater(
        pairing().resume(_remembered(), PairingAttempt()),
        throwsA(isA<PairingFailure>()),
      );
      expect(camera.calls, ['Connect', 'Disconnect']);
      expect(camera.characteristics['a0']!.writes, isEmpty);
      expect(camera.characteristics['a4']!.writes, isEmpty);
    },
  );

  test(
    'Given rediscovery without the remembered identity, Resume stops safely',
    () async {
      await service.unregisterObject(camera.device);
      final scan = _Adapter();
      await service.registerObject(scan);

      await expectLater(
        pairing().resume(_remembered(), PairingAttempt()),
        throwsA(
          _failureDuring('finding the remembered camera after discovery'),
        ),
      );

      expect(scan.calls, [
        'SetDiscoveryFilter',
        'StartDiscovery',
        'StopDiscovery',
      ]);
      expect(camera.calls, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given cancellation during rediscovery, Resume stops its scan without session writes',
    () async {
      await service.unregisterObject(camera.device);
      final scan = _Adapter();
      final attempt = PairingAttempt();
      scan.onStart = () async {
        attempt.cancel();
      };
      await service.registerObject(scan);

      await expectLater(
        pairing().resume(_remembered(), attempt),
        throwsA(isA<PairingFailure>()),
      );

      expect(camera.calls, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given missing session support, Pair stops before replacing a pairing',
    () async {
      await service.unregisterObject(camera.characteristics['a6']!);

      await expectLater(
        pairing().pair(camera.discovered, PairingAttempt()),
        throwsA(isA<PairingFailure>()),
      );

      expect(camera.calls, ['Connect', 'Disconnect']);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given command-only characteristics, writes use the advertised mode without fallback',
    () async {
      camera.characteristics['a0']!.flags = ['write-without-response'];
      camera.characteristics['a4']!.flags = ['write-without-response'];
      final adapter = pairing();
      final remembered = await adapter.pair(
        camera.discovered,
        PairingAttempt(),
      );
      await adapter.resume(remembered, PairingAttempt());

      expect(camera.characteristics['a0']!.writes.single.$2, 'command');
      expect(camera.characteristics['a4']!.writes.single.$2, 'command');
      expect(clients.every((client) => client.closed), isTrue);
    },
  );

  test(
    'Given session checksum input 123456789, Resume writes standard unsigned CRC32',
    () async {
      await pairing().resume(
        _remembered(referenceId: '2345', token: '6789'),
        PairingAttempt(),
      );

      expect(camera.characteristics['a4']!.writes.single, (
        '1,2345,3421780262',
        'request',
      ));
    },
  );

  test(
    'Given missing required capabilities, Pair fails before any writes',
    () async {
      for (final short in ['a0', 'a2', 'a4', 'a6', 'a7']) {
        final characteristic = camera.characteristics[short]!;
        final flags = characteristic.flags;
        characteristic.flags = [];
        camera.calls.clear();

        await expectLater(
          pairing().pair(camera.discovered, PairingAttempt()),
          throwsA(_failureDuring('checking pairing characteristics')),
        );

        expect(camera.calls, ['Connect', 'Disconnect'], reason: short);
        expect(clients.last.closed, isTrue);
        characteristic.flags = flags;
      }
    },
  );

  test('Given unsupported firmware, Pair does not request approval', () async {
    camera.characteristics['a2']!.bytes = ascii.encode('2,3.2-int,M1INT');

    await expectLater(
      pairing().pair(camera.discovered, PairingAttempt()),
      throwsA(_failureDuring('reading camera firmware')),
    );

    expect(camera.calls, ['Connect', 'Read:a2', 'Disconnect']);
    expect(clients.single.closed, isTrue);
  });

  test(
    'Given a failed pairing write, no fallback or second pairing is attempted and diagnostics are redacted',
    () async {
      camera.characteristics['a0']!.failure = 'WriteValue';

      final events = <LogEvent>[];
      await expectLater(
        pairing(
          log: AppLog(sink: events.add),
        ).pair(camera.discovered, PairingAttempt()),
        throwsA(_failureDuring('requesting camera approval')),
      );
      final failure = events
          .where((event) => event.event == 'ble.pair.failed')
          .single;
      expect(failure.level, LogLevel.error);
      expect(failure.code, 'permission_denied');
      expect(failure.stackTrace, isNotNull);
      expect(failure.elapsed, isNotNull);
      final text = events
          .map((e) => '${e.event} ${e.stage} ${e.code} ${e.stackTrace}')
          .join();
      for (final secret in [
        'private payload',
        'private address',
        '12345',
        'accepted-token',
      ]) {
        expect(text, isNot(contains(secret)));
      }

      expect(camera.calls.where((call) => call.startsWith('Write')), [
        'Write:a0',
      ]);
      expect(camera.calls.sublist(camera.calls.length - 2), [
        'StopNotify:a7',
        'Disconnect',
      ]);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given refusal or malformed tokens, Pair fails without session writes and cleans up',
    () async {
      for (final bytes in <List<int>>[
        [],
        [0, 0],
        [255],
        ascii.encode('private,token'),
        [65, 10],
        [65, 0, 66],
      ]) {
        camera.calls.clear();
        camera.characteristics['a0']!.onWrite = () =>
            camera.characteristics['a7']!.notify(bytes);

        await expectLater(
          pairing().pair(camera.discovered, PairingAttempt()),
          throwsA(
            isA<PairingFailure>().having(
              (failure) => failure.message,
              'message',
              allOf(
                contains(
                  bytes.every((byte) => byte == 0)
                      ? 'declined'
                      : 'waiting for camera approval',
                ),
                isNot(contains('private')),
              ),
            ),
          ),
        );

        expect(camera.calls.where((call) => call.startsWith('Write')), [
          'Write:a0',
        ]);
        expect(camera.calls.sublist(camera.calls.length - 2), [
          'StopNotify:a7',
          'Disconnect',
        ]);
        expect(clients.last.closed, isTrue);
      }
    },
  );

  test(
    'Given failed session authorization, Resume neither retries nor starts pairing',
    () async {
      camera.characteristics['a4']!.failure = 'WriteValue';

      await expectLater(
        pairing().resume(_remembered(), PairingAttempt()),
        throwsA(_failureDuring('starting the remembered camera session')),
      );

      expect(camera.calls, ['Connect', 'Write:a4', 'Disconnect']);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given denied credentials, Resume reports the read stage without exposing details',
    () async {
      camera.characteristics['a6']!.failure = 'ReadValue';

      await expectLater(
        pairing().resume(_remembered(), PairingAttempt()),
        throwsA(_failureDuring('reading camera Wi-Fi credentials')),
      );

      expect(camera.calls, ['Connect', 'Write:a4', 'Read:a6', 'Disconnect']);
      expect(clients.single.closed, isTrue);
    },
  );

  test('Given malformed credentials, Resume does not report success', () async {
    for (final value in [
      'private-network',
      ',private-password',
      'private-network,',
      'private-network,password,extra',
      'private-network,pass\nword',
    ]) {
      camera.characteristics['a6']!.bytes = ascii.encode(value);

      await expectLater(
        pairing().resume(_remembered(), PairingAttempt()),
        throwsA(_failureDuring('reading camera Wi-Fi credentials')),
      );

      expect(clients.last.closed, isTrue);
    }
  });

  test(
    'Given a stale selection, Pair does not connect to another cached device',
    () async {
      await expectLater(
        pairing().pair(
          const DiscoveredCamera(id: '/stale', name: 'YI M1'),
          PairingAttempt(),
        ),
        throwsA(_failureDuring('finding the selected camera')),
      );

      expect(camera.calls, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given a non-M1 cached device, matching the selection path alone cannot pair',
    () async {
      camera.device.uuids = [];

      await expectLater(
        pairing().pair(camera.discovered, PairingAttempt()),
        throwsA(_failureDuring('finding the selected camera')),
      );

      expect(camera.calls, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given a mismatched remembered address type, Resume does not connect',
    () async {
      camera.device.addressType = 'public';

      await expectLater(
        pairing().resume(_remembered(), PairingAttempt()),
        throwsA(
          _failureDuring('finding the remembered camera after discovery'),
        ),
      );

      expect(camera.calls, isEmpty);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given an existing connection, Pair does not borrow or disconnect it',
    () async {
      camera.device.connected = true;

      await expectLater(
        pairing().pair(camera.discovered, PairingAttempt()),
        throwsA(isA<PairingFailure>()),
      );

      expect(camera.calls, isEmpty);
      expect(clients.single.closed, isTrue);
      expect(camera.device.connected, isTrue);
    },
  );

  test(
    'Given cleanup failures after approval, material is preserved and the owned client still closes',
    () async {
      camera.characteristics['a7']!.failure = 'StopNotify';
      camera.device.failure = 'Disconnect';

      final events = <LogEvent>[];
      final result = await pairing(
        log: AppLog(sink: events.add),
      ).pair(camera.discovered, PairingAttempt());

      final warnings = events
          .where((event) => event.level == LogLevel.warning)
          .toList();
      expect(warnings, hasLength(2));
      expect(warnings.map((event) => event.code), [
        'permission_denied',
        'dbus_method_failed',
      ]);
      expect(
        warnings.every(
          (event) => event.elapsed != null && event.stackTrace != null,
        ),
        isTrue,
      );
      expect(events.last.event, 'ble.pair.succeeded');
      final text = events
          .map((e) => '${e.event} ${e.stage} ${e.code} ${e.stackTrace}')
          .join();
      expect(text, isNot(contains('private payload')));
      expect(text, isNot(contains('private address')));
      expect(result.token, 'accepted-token');
      expect(camera.calls.sublist(camera.calls.length - 2), [
        'StopNotify:a7',
        'Disconnect',
      ]);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given canceled attempt, Pair creates no client or camera operation',
    () async {
      final attempt = PairingAttempt()..cancel();

      await expectLater(
        pairing().pair(camera.discovered, attempt),
        throwsA(isA<PairingFailure>()),
      );

      expect(clients, isEmpty);
      expect(camera.calls, isEmpty);
    },
  );

  for (final short in ['a2', 'a7']) {
    test(
      'Given timeout during $short followed by late completion, no pairing write can run',
      () async {
        final entered = Completer<void>();
        final release = Completer<void>();
        final returned = Completer<void>();
        Future<void> block() async {
          entered.complete();
          await release.future;
          returned.complete();
        }

        if (short == 'a2') {
          camera.characteristics[short]!.onRead = block;
        } else {
          camera.characteristics[short]!.onStartNotify = block;
        }
        final result = pairing().pair(
          camera.discovered,
          PairingAttempt(limit: const Duration(milliseconds: 150)),
        );
        final failure = expectLater(
          result,
          throwsA(
            _failureDuring(
              short == 'a2'
                  ? 'reading camera firmware'
                  : 'subscribing for camera approval',
            ),
          ),
        );
        await entered.future;
        await failure;
        expect(clients.single.closed, isTrue);
        release.complete();
        await returned.future;

        expect(camera.calls.where((call) => call.startsWith('Write')), isEmpty);
        expect(camera.calls.last, 'Disconnect');
      },
    );
  }

  test(
    'Given unresolved services until timeout, Pair performs no GATT reads or writes and disconnects',
    () async {
      camera.device.resolveOnConnect = false;

      await expectLater(
        pairing().pair(
          camera.discovered,
          PairingAttempt(limit: const Duration(milliseconds: 150)),
        ),
        throwsA(_failureDuring('resolving camera services')),
      );

      expect(camera.calls, ['Connect', 'Disconnect']);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given no camera approval before timeout, Pair stops notifications and never retries',
    () async {
      camera.characteristics['a0']!.onWrite = null;

      await expectLater(
        pairing().pair(
          camera.discovered,
          PairingAttempt(limit: const Duration(milliseconds: 150)),
        ),
        throwsA(_failureDuring('waiting for camera approval')),
      );

      expect(camera.calls, [
        'Connect',
        'Read:a2',
        'StartNotify:a7',
        'Write:a0',
        'StopNotify:a7',
        'Disconnect',
      ]);
      expect(camera.characteristics['a0']!.writes, hasLength(1));
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given camera approval, Pair returns reusable material and releases only its connection',
    () async {
      final result = await pairing().pair(camera.discovered, PairingAttempt());

      expect(result.address, 'AA:BB:CC:DD:EE:FF');
      expect(result.addressType, 'random');
      expect(result.protocol, 1);
      expect(result.referenceId, '12345');
      expect(result.token, 'accepted-token');
      expect(camera.calls, [
        'Connect',
        'Read:a2',
        'StartNotify:a7',
        'Write:a0',
        'StopNotify:a7',
        'Disconnect',
      ]);
      expect(camera.characteristics['a0']!.writes.single, (
        '1,12345,android',
        'request',
      ));
      expect(clients.single.closed, isTrue);
    },
  );
}

RememberedCamera _remembered({
  String referenceId = '12345',
  String token = 'accepted-token',
}) => RememberedCamera(
  address: 'AA:BB:CC:DD:EE:FF',
  addressType: 'random',
  protocol: 1,
  referenceId: referenceId,
  token: token,
);

Matcher _failureDuring(String stage) => isA<PairingFailure>().having(
  (failure) => failure.message,
  'message',
  allOf(contains(stage), isNot(contains('private'))),
);

class _OwnedClient extends BlueZClient {
  _OwnedClient(
    this.bus, {
    this.deviceAddedOverride,
    this.deviceProperties,
    this.connectError,
    this.closeError,
  }) : super(bus: bus);
  final Stream<List<String>>? deviceProperties;
  @override
  List<BlueZDevice> get devices => deviceProperties == null
      ? super.devices
      : super.devices
            .map((device) => _DeviceWithStream(device, deviceProperties!))
            .toList();
  final Object? connectError;
  final Object? closeError;
  @override
  Future<void> connect() async {
    if (connectError != null) throw connectError!;
    await super.connect();
  }

  final Stream<BlueZDevice>? deviceAddedOverride;
  @override
  Stream<BlueZDevice> get deviceAdded =>
      deviceAddedOverride ?? super.deviceAdded;
  final DBusClient bus;
  bool closed = false;

  @override
  Future<void> close() async {
    if (closed) return;
    await super.close();
    await bus.close();
    closed = true;
    if (closeError != null) throw closeError!;
  }
}

class _DeviceWithStream implements BlueZDevice {
  _DeviceWithStream(this.delegate, this.propertiesChanged);
  final BlueZDevice delegate;
  @override
  final Stream<List<String>> propertiesChanged;
  @override
  DBusObjectPath get path => delegate.path;
  @override
  List<BlueZUUID> get uuids => delegate.uuids;
  @override
  String get address => delegate.address;
  @override
  BlueZAddressType get addressType => delegate.addressType;
  @override
  bool get connected => delegate.connected;
  @override
  bool get servicesResolved => delegate.servicesResolved;
  @override
  List<BlueZGattService> get gattServices => delegate.gattServices;
  @override
  Future<void> connect() => delegate.connect();
  @override
  Future<void> disconnect() => delegate.disconnect();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Camera {
  _Camera() {
    device = _Device(calls);
    for (final (short, flags, value) in [
      ('a2', ['read'], '1,3.2-int,M1INT,0.0'),
      ('a0', ['write', 'write-without-response'], ''),
      ('a7', ['notify'], ''),
      ('a4', ['write'], ''),
      ('a5', ['write'], ''),
      ('a6', ['read'], 'camera-network,session-password'),
    ]) {
      characteristics[short] = _Characteristic(
        short,
        flags,
        ascii.encode(value),
        calls,
      );
    }
    characteristics['a0']!.onWrite = () =>
        characteristics['a7']!.notify(ascii.encode('accepted-token') + [0, 0]);
  }

  final calls = <String>[];
  final gattService = _GattService();
  late final _Device device;
  final characteristics = <String, _Characteristic>{};
  DiscoveredCamera get discovered =>
      DiscoveredCamera(id: device.path.value, name: 'YI M1 1');

  Future<void> register(DBusClient service) async {
    await service.registerObject(_Adapter());
    await service.registerObject(device);
    await service.registerObject(gattService);
    for (final characteristic in characteristics.values) {
      await service.registerObject(characteristic);
    }
  }
}

class _Adapter extends DBusObject {
  _Adapter() : super(DBusObjectPath('/org/bluez/hci0'));
  final calls = <String>[];
  Map<String, DBusValue> filter = {};
  Future<void> Function()? onStart;

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    calls.add(call.name);
    switch (call.name) {
      case 'SetDiscoveryFilter':
        filter = call.values.single.asStringVariantDict();
      case 'StartDiscovery':
        await onStart?.call();
      case 'StopDiscovery':
        break;
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    'org.bluez.Adapter1': {
      'Powered': const DBusBoolean(true),
      'Address': const DBusString('adapter'),
    },
  };
}

class _Device extends DBusObject {
  _Device(this.calls) : super(DBusObjectPath('/org/bluez/hci0/dev_camera'));
  final List<String> calls;
  bool connected = false;
  bool resolveOnConnect = true;
  String addressType = 'random';
  List<String> uuids = [serviceUuid];
  final didConnect = Completer<void>();
  String? failure;

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    'org.bluez.Device1': {
      'Adapter': DBusObjectPath('/org/bluez/hci0'),
      'Address': const DBusString('AA:BB:CC:DD:EE:FF'),
      'AddressType': DBusString(addressType),
      'Name': const DBusString('private camera name'),
      'UUIDs': DBusArray.string(uuids),
      'Connected': DBusBoolean(connected),
      'ServicesResolved': const DBusBoolean(false),
    },
  };

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    calls.add(call.name);
    if (call.name == failure) {
      return DBusMethodErrorResponse('org.bluez.Error.Failed', [
        const DBusString('private address'),
      ]);
    }
    if (call.name == 'Connect') {
      if (!didConnect.isCompleted) didConnect.complete();
      connected = true;
      await emitPropertiesChanged(
        'org.bluez.Device1',
        changedProperties: {
          'Connected': const DBusBoolean(true),
          'ServicesResolved': DBusBoolean(resolveOnConnect),
        },
      );
      return DBusMethodSuccessResponse();
    }
    if (call.name == 'Disconnect') {
      connected = false;
      return DBusMethodSuccessResponse();
    }
    return DBusMethodErrorResponse.unknownMethod();
  }
}

class _GattService extends DBusObject {
  _GattService() : super(DBusObjectPath('/org/bluez/hci0/dev_camera/service0'));

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    'org.bluez.GattService1': {
      'UUID': const DBusString(serviceUuid),
      'Device': DBusObjectPath('/org/bluez/hci0/dev_camera'),
      'Primary': const DBusBoolean(true),
    },
  };
}

class _Characteristic extends DBusObject {
  _Characteristic(this.short, this.flags, this.bytes, this.calls)
    : super(DBusObjectPath('/org/bluez/hci0/dev_camera/service0/char_$short'));
  final String short;
  List<String> flags;
  List<int> bytes;
  final List<String> calls;
  final writes = <(String, String)>[];
  Future<void> Function()? onWrite;
  Future<void> Function()? onRead;
  Future<void> Function()? onStartNotify;
  String? failure;

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    'org.bluez.GattCharacteristic1': {
      'UUID': DBusString(characteristicUuid(short)),
      'Service': DBusObjectPath('/org/bluez/hci0/dev_camera/service0'),
      'Flags': DBusArray.string(flags),
      'Value': DBusArray.byte(bytes),
    },
  };

  Future<void> notify(List<int> value) => emitPropertiesChanged(
    'org.bluez.GattCharacteristic1',
    changedProperties: {'Value': DBusArray.byte(value)},
  );

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    final operation = switch (call.name) {
      'ReadValue' => 'Read',
      'WriteValue' => 'Write',
      _ => call.name,
    };
    calls.add('$operation:$short');
    if (call.name == failure) {
      return DBusMethodErrorResponse('org.bluez.Error.NotAuthorized', [
        const DBusString('private payload and address'),
      ]);
    }
    switch (call.name) {
      case 'ReadValue':
        await onRead?.call();
        return DBusMethodSuccessResponse([DBusArray.byte(bytes)]);
      case 'WriteValue':
        writes.add((
          ascii.decode(call.values[0].asByteArray().toList()),
          call.values[1].asStringVariantDict()['type']!.asString(),
        ));
        await onWrite?.call();
        return DBusMethodSuccessResponse();
      case 'StartNotify':
        await onStartNotify?.call();
        return DBusMethodSuccessResponse();
      case 'StopNotify':
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }
}
