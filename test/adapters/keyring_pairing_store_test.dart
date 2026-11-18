import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:yi_m1_reborn/adapters/linux/keyring_pairing_store.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import 'package:yi_m1_reborn/application/diagnostics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const camera = RememberedCamera(
    address: '00:11:22:33:44:55',
    addressType: 'public',
    protocol: 1,
    referenceId: 'test-reference',
    token: 'test-token',
  );
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<String, String> records;
  PlatformException? readFailure;
  PlatformException? writeFailure;
  late bool silentlyDropWrites;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    calls = [];
    records = {};
    readFailure = null;
    writeFailure = null;
    silentlyDropWrites = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      final arguments = call.arguments as Map<Object?, Object?>;
      final key = arguments['key']! as String;
      if (call.method == 'read') {
        if (readFailure != null) throw readFailure!;
        final value = records[key];
        return value == '' ? null : value;
      }
      if (call.method == 'containsKey') return records.containsKey(key);
      if (call.method == 'write') {
        if (writeFailure != null) throw writeFailure!;
        if (!silentlyDropWrites) records[key] = arguments['value']! as String;
        return null;
      }
      throw StateError('Unexpected storage operation');
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'Given no stored pairing, diagnostics report an empty read without secrets',
    () async {
      final events = <LogEvent>[];
      final store = KeyringPairingStore(log: AppLog(sink: events.add));

      expect(await store.read(), isNull);

      expect(events.map((event) => event.event), [
        'storage.read.started',
        'storage.read.empty',
      ]);
      expect(events.every((event) => event.level == LogLevel.info), isTrue);
      expect(events.last.elapsed, isNotNull);
    },
  );

  test(
    'Given no stored pairing, reading returns no remembered camera',
    () async {
      expect(await KeyringPairingStore().read(), isNull);
      expect(calls.map((call) => call.method), ['read', 'containsKey']);
    },
  );

  test(
    'Given an authorized pairing, saving and reading retains only pairing material',
    () async {
      final events = <LogEvent>[];
      final store = KeyringPairingStore(log: AppLog(sink: events.add));

      await store.save(camera);
      final remembered = await store.read();
      expect(
        events
            .where((event) => event.event == 'storage.save.succeeded')
            .single
            .elapsed,
        isNotNull,
      );
      expect(
        events.where((event) => event.event == 'storage.read.succeeded'),
        hasLength(2),
      );
      final rendered = events
          .map(
            (event) =>
                '${event.event} ${event.stage} ${event.code} ${event.stackTrace}',
          )
          .join();
      for (final secret in [camera.address, camera.referenceId, camera.token]) {
        expect(rendered, isNot(contains(secret)));
      }

      expect(records, hasLength(1));
      expect(jsonDecode(records.values.single), {
        'version': 1,
        'address': camera.address,
        'addressType': camera.addressType,
        'protocol': camera.protocol,
        'referenceId': camera.referenceId,
        'token': camera.token,
      });
      expect(remembered, isNotNull);
      expect(remembered!.address, camera.address);
      expect(remembered.addressType, camera.addressType);
      expect(remembered.protocol, camera.protocol);
      expect(remembered.referenceId, camera.referenceId);
      expect(remembered.token, camera.token);
      expect(calls.map((call) => call.method), ['write', 'read', 'read']);
    },
  );

  test(
    'Given a platform read failure, diagnostics retain only a safe cause and stack',
    () async {
      final events = <LogEvent>[];
      readFailure = PlatformException(
        code: camera.token,
        message: camera.address,
        details: camera.referenceId,
      );

      await expectLater(
        KeyringPairingStore(log: AppLog(sink: events.add)).read(),
        throwsA(isA<PairingStorageFailure>()),
      );

      final failure = events.last;
      expect(failure.event, 'storage.read.failed');
      expect(failure.level, LogLevel.error);
      expect(failure.stage, 'read');
      expect(failure.code, 'platform');
      expect(failure.elapsed, isNotNull);
      expect(failure.stackTrace, isNotNull);
      final rendered = events
          .map(
            (event) =>
                '${event.event} ${event.stage} ${event.code} ${event.stackTrace}',
          )
          .join();
      for (final secret in [camera.address, camera.referenceId, camera.token]) {
        expect(rendered, isNot(contains(secret)));
      }
    },
  );

  test(
    'Given a locked keyring, reading fails rather than forgetting the camera',
    () async {
      readFailure = PlatformException(code: 'KeyringLocked');

      await expectLater(
        KeyringPairingStore().read(),
        throwsA(isA<PairingStorageFailure>()),
      );
      expect(records, isEmpty);
      expect(calls.map((call) => call.method), ['read']);
    },
  );

  test(
    'Given an unavailable keyring, saving fails without reporting success',
    () async {
      writeFailure = PlatformException(code: 'Libsecret error');

      await expectLater(
        KeyringPairingStore().save(camera),
        throwsA(isA<PairingStorageFailure>()),
      );
      expect(records, isEmpty);
      expect(calls.map((call) => call.method), ['write']);
    },
  );

  test(
    'Given malformed stored JSON, reading reports a storage failure',
    () async {
      final store = KeyringPairingStore();
      await store.save(camera);
      records[records.keys.single] = '{broken';
      calls.clear();

      await expectLater(store.read(), throwsA(isA<PairingStorageFailure>()));
      expect(calls.map((call) => call.method), ['read']);
    },
  );

  test('Given an invalid record shape, reading fails closed', () async {
    final store = KeyringPairingStore();
    await store.save(camera);
    final key = records.keys.single;
    final valid = jsonDecode(records[key]!) as Map<String, dynamic>;
    final invalidRecords = <Object?>[
      [],
      {...valid, 'version': 2},
      {...valid}..remove('token'),
      {...valid, 'protocol': '1'},
      {...valid, 'token': ''},
      {...valid, 'wifiPassword': 'must-not-be-stored'},
    ];

    for (final record in invalidRecords) {
      records[key] = jsonEncode(record);
      await expectLater(store.read(), throwsA(isA<PairingStorageFailure>()));
    }
  });

  test(
    'Given an unavailable plugin channel, reads and writes report storage failure',
    () async {
      messenger.setMockMethodCallHandler(channel, null);
      final store = KeyringPairingStore();

      await expectLater(store.read(), throwsA(isA<PairingStorageFailure>()));
      await expectLater(
        store.save(camera),
        throwsA(isA<PairingStorageFailure>()),
      );
    },
  );

  test(
    'Given a programming error in storage, reading propagates it with diagnostics',
    () async {
      for (final error in [
        StateError('private programming failure'),
        TypeError(),
      ]) {
        final events = <LogEvent>[];
        final store = KeyringPairingStore(
          log: AppLog(sink: events.add),
          storage: _FailingStorage(error),
        );

        await expectLater(store.read(), throwsA(same(error)));

        expect(events.last.level, LogLevel.error);
        expect(events.last.code, 'unexpected');
        expect(events.last.stackTrace, isNotNull);
        events.clear();
        await expectLater(store.save(camera), throwsA(same(error)));
        expect(events.last.event, 'storage.save.failed');
        expect(events.last.code, 'unexpected');
        expect(events.last.stackTrace, isNotNull);
      }
    },
  );

  test(
    'Given an invalid typed plugin response, reading propagates the type error',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => 42);
      final events = <LogEvent>[];

      await expectLater(
        KeyringPairingStore(log: AppLog(sink: events.add)).read(),
        throwsA(isA<TypeError>()),
      );
      expect(events.last.code, 'unexpected');
      expect(events.last.stackTrace, isNotNull);
    },
  );

  test(
    'Given an existing empty record hidden by the native plugin, reading fails closed',
    () async {
      final store = KeyringPairingStore();
      await store.save(camera);
      records[records.keys.single] = '';
      calls.clear();

      await expectLater(store.read(), throwsA(isA<PairingStorageFailure>()));
      expect(calls.map((call) => call.method), ['read', 'containsKey']);
    },
  );

  test(
    'Given a native write that silently stores nothing, saving fails',
    () async {
      silentlyDropWrites = true;

      await expectLater(
        KeyringPairingStore().save(camera),
        throwsA(isA<PairingStorageFailure>()),
      );
      expect(records, isEmpty);
    },
  );

  test(
    'Given a native write that leaves stale pairing material, saving fails',
    () async {
      final store = KeyringPairingStore();
      await store.save(camera);
      silentlyDropWrites = true;
      final updated = RememberedCamera(
        address: camera.address,
        addressType: camera.addressType,
        protocol: camera.protocol,
        referenceId: camera.referenceId,
        token: 'updated-test-token',
      );

      await expectLater(
        store.save(updated),
        throwsA(isA<PairingStorageFailure>()),
      );
    },
  );
}

class _FailingStorage extends FlutterSecureStorage {
  _FailingStorage(this.error);
  final Object error;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => Future<String?>.error(error, StackTrace.current);

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) => Future<void>.error(error, StackTrace.current);
}
