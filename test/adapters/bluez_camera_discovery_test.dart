import 'dart:async';
import 'dart:io';

import 'package:bluez/bluez.dart';
import 'package:dbus/dbus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/adapters/linux/bluez_camera_discovery.dart';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/application/diagnostics.dart';

const cameraService = '41106dd9-25ad-477b-a884-5038b6de4649';

void main() {
  late DBusServer server;
  late DBusClient service;
  late DBusAddress address;
  late List<_OwnedBlueZClient> clients;

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
  });

  tearDown(() async {
    for (final client in clients) {
      await client.close();
    }
    await service.close();
    await server.close();
  });

  BluezCameraDiscovery discovery({
    Duration scanDuration = const Duration(milliseconds: 20),
    Duration operationLimit = const Duration(seconds: 120),
    Completer<void>? connectGate,
    Completer<void>? closeGate,
    AppLog log = const AppLog(),
  }) => BluezCameraDiscovery(
    createClient: () {
      final client = _OwnedBlueZClient(
        DBusClient(address),
        connectGate: connectGate,
        closeGate: closeGate,
      );
      clients.add(client);
      return client;
    },
    log: log,
    scanDuration: scanDuration,
    operationLimit: operationLimit,
  );

  test(
    'Given a successful scan, diagnostics show stages and safe outcomes',
    () async {
      await service.registerObject(_Adapter('/org/bluez/hci0'));
      final events = <LogEvent>[];

      await discovery(
        log: AppLog(sink: events.add, minimumLevel: LogLevel.debug),
      ).discover();

      expect(events.first.event, 'ble.discovery.started');
      expect(events.last.event, 'ble.discovery.succeeded');
      expect(events.last.level, LogLevel.info);
      expect(events.last.elapsed, isNotNull);
      expect(events.where((event) => event.stage == 'scanning'), isNotEmpty);
      expect(
        events.where((event) => event.level == LogLevel.debug),
        isNotEmpty,
      );
      expect(events.every((event) => event.elapsed != null), isTrue);
    },
  );

  test(
    'Given discovery and cleanup programming errors, the primary error survives with separate diagnostics',
    () async {
      final primary = StateError('private primary detail');
      final cleanup = StateError('private cleanup detail');
      final events = <LogEvent>[];
      final adapter = BluezCameraDiscovery(
        log: AppLog(sink: events.add),
        createClient: () {
          final client = _OwnedBlueZClient(
            DBusClient(address),
            connectError: primary,
            closeError: cleanup,
          );
          clients.add(client);
          return client;
        },
      );

      await expectLater(adapter.discover(), throwsA(same(primary)));
      expect(clients.single.closed, isTrue);
      expect(
        events
            .where((event) => event.event == 'ble.discovery.failed')
            .single
            .code,
        'unexpected',
      );
      final cleanupEvent = events
          .where((event) => event.event == 'ble.discovery.cleanup.failed')
          .single;
      expect(cleanupEvent.level, LogLevel.error);
      expect(cleanupEvent.stackTrace, isNotNull);
      expect(
        events.where((event) => event.event == 'ble.discovery.succeeded'),
        isEmpty,
      );
    },
  );

  test(
    'Given an unexpected client error, discovery preserves the error',
    () async {
      final error = StateError('private programming detail');
      final adapter = BluezCameraDiscovery(createClient: () => throw error);

      await expectLater(adapter.discover(), throwsA(same(error)));
    },
  );

  test(
    'Given stalled Bluetooth setup, the budget closes the client and late setup cannot scan',
    () async {
      final adapter = _Adapter('/org/bluez/hci0');
      await service.registerObject(adapter);
      final gate = Completer<void>();
      final cameraDiscovery = discovery(
        connectGate: gate,
        operationLimit: const Duration(milliseconds: 100),
      );

      await expectLater(
        cameraDiscovery.discover().timeout(const Duration(seconds: 2)),
        throwsA(isA<DiscoveryFailure>()),
      );
      expect(clients.single.closed, isTrue);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.calls, isEmpty);
    },
  );

  test(
    'Given a stalled discovery filter, timeout closes the client and late completion cannot start scanning',
    () async {
      final gate = Completer<void>();
      final adapter = _Adapter(
        '/org/bluez/hci0',
        stalledCall: 'SetDiscoveryFilter',
        gate: gate,
      );
      await service.registerObject(adapter);

      await expectLater(
        discovery(
          operationLimit: const Duration(milliseconds: 100),
        ).discover().timeout(const Duration(seconds: 2)),
        throwsA(isA<DiscoveryFailure>()),
      );
      expect(clients.single.closed, isTrue);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.calls, ['SetDiscoveryFilter']);
    },
  );

  test(
    'Given stalled scan start, timeout closes the client and late completion cannot continue discovery',
    () async {
      final gate = Completer<void>();
      final adapter = _Adapter(
        '/org/bluez/hci0',
        stalledCall: 'StartDiscovery',
        gate: gate,
      );
      await service.registerObject(adapter);

      await expectLater(
        discovery(
          operationLimit: const Duration(milliseconds: 100),
        ).discover().timeout(const Duration(seconds: 2)),
        throwsA(isA<DiscoveryFailure>()),
      );
      expect(clients.single.closed, isTrue);
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.calls, ['SetDiscoveryFilter', 'StartDiscovery']);
    },
  );

  test(
    'Given a scan window longer than the remaining budget, discovery fails and releases scanning',
    () async {
      final adapter = _Adapter('/org/bluez/hci0');
      await service.registerObject(adapter);

      await expectLater(
        discovery(
          operationLimit: const Duration(milliseconds: 100),
          scanDuration: const Duration(seconds: 1),
        ).discover(),
        throwsA(isA<DiscoveryFailure>()),
      );

      expect(adapter.calls, [
        'SetDiscoveryFilter',
        'StartDiscovery',
        'StopDiscovery',
      ]);
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given stalled scan cleanup, discovery reports failure and still closes its client',
    () async {
      final gate = Completer<void>();
      final adapter = _Adapter(
        '/org/bluez/hci0',
        stalledCall: 'StopDiscovery',
        gate: gate,
      );
      await service.registerObject(adapter);

      try {
        await expectLater(
          discovery().discover().timeout(const Duration(seconds: 2)),
          throwsA(isA<DiscoveryFailure>()),
        );
        expect(clients.single.closed, isTrue);
        expect(adapter.calls.last, 'StopDiscovery');
      } finally {
        gate.complete();
      }
    },
  );

  test(
    'Given stalled client cleanup, discovery reports failure within the cleanup bound',
    () async {
      final adapter = _Adapter('/org/bluez/hci0');
      await service.registerObject(adapter);
      final gate = Completer<void>();

      try {
        await expectLater(
          discovery(
            closeGate: gate,
          ).discover().timeout(const Duration(seconds: 2)),
          throwsA(isA<DiscoveryFailure>()),
        );
        expect(clients.single.closed, isTrue);
        expect(adapter.calls.last, 'StopDiscovery');
      } finally {
        gate.complete();
      }
    },
  );

  test(
    'Given no matching cameras, discovery filters LE and releases its session',
    () async {
      final adapter = _Adapter('/org/bluez/hci0');
      await service.registerObject(adapter);

      expect(await discovery().discover(), isEmpty);

      expect(adapter.calls, [
        'SetDiscoveryFilter',
        'StartDiscovery',
        'StopDiscovery',
      ]);
      expect(adapter.filter['UUIDs']?.asStringArray(), [cameraService]);
      expect(adapter.filter['Transport']?.asString(), 'le');
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given advertised devices, only matching cameras on the chosen adapter are returned',
    () async {
      final adapter = _Adapter('/org/bluez/hci0');
      final otherAdapter = _Adapter('/org/bluez/hci1');
      await service.registerObject(adapter);
      await service.registerObject(otherAdapter);
      final first = _Device(
        adapter,
        'one',
        uuids: [cameraService.toUpperCase()],
      );
      final second = _Device(adapter, 'two', uuids: [cameraService]);
      final unrelated = _Device(adapter, 'speaker', uuids: []);
      final otherCamera = _Device(
        otherAdapter,
        'other',
        uuids: [cameraService],
      );
      for (final device in [first, second, unrelated, otherCamera]) {
        await service.registerObject(device);
      }

      final cameras = await discovery().discover();

      expect(cameras.map((camera) => camera.id), [
        first.path.value,
        second.path.value,
      ]);
      expect(cameras.map((camera) => camera.name), ['YI M1 1', 'YI M1 2']);
      expect(otherAdapter.calls, isEmpty);
      expect(
        [
          first,
          second,
          unrelated,
          otherCamera,
        ].expand((device) => device.calls),
        isEmpty,
      );
      expect(clients.single.closed, isTrue);
    },
  );

  test(
    'Given several adapters, discovery uses the first powered one without changing power',
    () async {
      final off = _Adapter('/org/bluez/hci0', powered: false);
      final on = _Adapter('/org/bluez/hci1');
      final unused = _Adapter('/org/bluez/hci2');
      for (final adapter in [off, on, unused]) {
        await service.registerObject(adapter);
      }

      await discovery().discover();

      expect(off.calls, isEmpty);
      expect(on.calls, [
        'SetDiscoveryFilter',
        'StartDiscovery',
        'StopDiscovery',
      ]);
      expect(unused.calls, isEmpty);
    },
  );

  test(
    'Given absent or unpowered Bluetooth, discovery fails safely and closes each attempt',
    () async {
      final cameraDiscovery = discovery();
      final failure = isA<DiscoveryFailure>().having(
        (error) => error.message,
        'message',
        contains('Bluetooth'),
      );
      await expectLater(cameraDiscovery.discover(), throwsA(failure));
      final off = _Adapter('/org/bluez/hci0', powered: false);
      await service.registerObject(off);
      await expectLater(cameraDiscovery.discover(), throwsA(failure));

      expect(off.calls, isEmpty);
      expect(clients, hasLength(2));
      expect(clients.every((client) => client.closed), isTrue);
    },
  );

  test(
    'Given a BlueZ failure, discovery redacts the error and closes its client',
    () async {
      final adapter = _Adapter('/org/bluez/hci0');
      await service.registerObject(adapter);
      final cameraDiscovery = discovery();
      for (final failedCall in [
        'SetDiscoveryFilter',
        'StartDiscovery',
        'StopDiscovery',
      ]) {
        adapter.failure = failedCall;
        adapter.calls.clear();

        await expectLater(
          cameraDiscovery.discover(),
          throwsA(
            isA<DiscoveryFailure>().having(
              (error) => error.message,
              'message',
              allOf(contains('Bluetooth'), isNot(contains('private'))),
            ),
          ),
        );

        expect(adapter.calls, switch (failedCall) {
          'SetDiscoveryFilter' => ['SetDiscoveryFilter'],
          'StartDiscovery' => ['SetDiscoveryFilter', 'StartDiscovery'],
          _ => ['SetDiscoveryFilter', 'StartDiscovery', 'StopDiscovery'],
        });
        expect(clients.last.closed, isTrue);
      }
    },
  );

  test(
    'Given devices arriving during discovery, new advertisements and UUID updates are included once',
    () async {
      final adapter = _Adapter('/org/bluez/hci0');
      await service.registerObject(adapter);
      final pending = _Device(adapter, 'pending', uuids: []);
      await service.registerObject(pending);
      final cameraDiscovery = discovery(
        scanDuration: const Duration(milliseconds: 100),
      );

      final result = cameraDiscovery.discover();
      await adapter.started.future;
      final arriving = _Device(adapter, 'arriving', uuids: [cameraService]);
      await service.registerObject(arriving);
      await pending.emitPropertiesChanged(
        'org.bluez.Device1',
        changedProperties: {
          'UUIDs': DBusArray.string([cameraService]),
        },
      );
      await pending.emitPropertiesChanged(
        'org.bluez.Device1',
        changedProperties: {
          'UUIDs': DBusArray.string([cameraService]),
        },
      );
      final cameras = await result;

      expect(cameras.map((camera) => camera.id), [
        pending.path.value,
        arriving.path.value,
      ]);
      expect(adapter.calls.last, 'StopDiscovery');
      expect(clients.single.closed, isTrue);
    },
  );
}

class _OwnedBlueZClient extends BlueZClient {
  _OwnedBlueZClient(
    this.bus, {
    this.connectGate,
    this.closeGate,
    this.connectError,
    this.closeError,
  }) : super(bus: bus);

  final Object? connectError;
  final Object? closeError;
  final Completer<void>? connectGate;
  final Completer<void>? closeGate;

  @override
  Future<void> connect() async {
    if (connectError != null) throw connectError!;
    await super.connect();
    await connectGate?.future;
  }

  final DBusClient bus;
  bool closed = false;

  @override
  Future<void> close() async {
    if (closed) return;
    await super.close();
    await bus.close();
    closed = true;
    await closeGate?.future;
    if (closeError != null) throw closeError!;
  }
}

class _Adapter extends DBusObject {
  _Adapter(String path, {this.powered = true, this.stalledCall, this.gate})
    : super(DBusObjectPath(path));

  final String? stalledCall;
  final Completer<void>? gate;

  final bool powered;
  final calls = <String>[];
  String? failure;
  final started = Completer<void>();
  Map<String, DBusValue> filter = {};

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    'org.bluez.Adapter1': {
      'Powered': DBusBoolean(powered),
      'Address': DBusString(path.value),
    },
  };

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    calls.add(call.name);
    if (call.interface != 'org.bluez.Adapter1') {
      return DBusMethodErrorResponse.unknownInterface();
    }
    if (call.name == stalledCall) await gate!.future;
    if (call.name == failure) {
      return DBusMethodErrorResponse('org.bluez.Error.NotAuthorized', [
        const DBusString('private path or device identifier'),
      ]);
    }
    switch (call.name) {
      case 'SetDiscoveryFilter':
        filter = call.values.single.asStringVariantDict();
        return DBusMethodSuccessResponse();
      case 'StartDiscovery':
        if (!started.isCompleted) started.complete();
        return DBusMethodSuccessResponse();
      case 'StopDiscovery':
        return DBusMethodSuccessResponse();
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    calls.add('Set:$name');
    return DBusMethodErrorResponse.propertyReadOnly();
  }
}

class _Device extends DBusObject {
  _Device(this.adapter, String id, {required this.uuids})
    : super(DBusObjectPath('${adapter.path.value}/dev_$id'));

  final _Adapter adapter;
  final List<String> uuids;
  final calls = <String>[];

  @override
  Map<String, Map<String, DBusValue>> get interfacesAndProperties => {
    'org.bluez.Device1': {
      'Adapter': adapter.path,
      'UUIDs': DBusArray.string(uuids),
      'Address': const DBusString('AA:BB:CC:DD:EE:FF'),
      'Name': const DBusString('private camera name'),
      'Alias': const DBusString('AA-BB-CC-DD-EE-FF'),
    },
  };

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    calls.add(call.name);
    return DBusMethodErrorResponse.unknownMethod();
  }

  @override
  Future<DBusMethodResponse> setProperty(
    String interface,
    String name,
    DBusValue value,
  ) async {
    calls.add('Set:$name');
    return DBusMethodErrorResponse.propertyReadOnly();
  }
}
