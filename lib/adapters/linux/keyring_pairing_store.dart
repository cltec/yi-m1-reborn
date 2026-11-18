import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../application/camera_pairing.dart';
import '../../application/diagnostics.dart';

class KeyringPairingStore implements PairingStore {
  KeyringPairingStore({
    AppLog log = const AppLog(),
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _log = log,
       _storage = storage;

  final AppLog _log;
  final FlutterSecureStorage _storage;
  // LinuxOptions has no namespace setting; the Linux plugin scopes its account
  // by APPLICATION_ID, set to dev.cltec.yi_m1_reborn by the Linux runner.
  static const _key = 'dev.cltec.yi_m1_reborn.pairing';

  @override
  Future<RememberedCamera?> read() async {
    final clock = Stopwatch()..start();
    var stage = 'read';
    _log.emit(LogLevel.info, 'storage.read.started', stage: stage);
    try {
      final record = await _storage.read(key: _key);
      if (record == null) {
        stage = 'contains_key';
        final present = await _storage.containsKey(key: _key);
        // Linux returns null for an existing empty/non-string value too.
        if (present) {
          throw const PairingStorageFailure();
        }
        _log.emit(
          LogLevel.info,
          'storage.read.empty',
          stage: 'read',
          elapsed: clock.elapsed,
        );
        return null;
      }
      stage = 'decode';
      final Object? value = jsonDecode(record);
      stage = 'validate';
      if (value is! Map<String, dynamic> || value.length != 6) {
        throw const PairingStorageFailure();
      }
      if (value
          case {
            'version': int version,
            'address': String address,
            'addressType': String addressType,
            'protocol': int protocol,
            'referenceId': String referenceId,
            'token': String token,
          }
          when version == 1 &&
              address.isNotEmpty &&
              addressType.isNotEmpty &&
              referenceId.isNotEmpty &&
              token.isNotEmpty) {
        final camera = RememberedCamera(
          address: address,
          addressType: addressType,
          protocol: protocol,
          referenceId: referenceId,
          token: token,
        );
        _log.emit(
          LogLevel.info,
          'storage.read.succeeded',
          stage: stage,
          elapsed: clock.elapsed,
        );
        return camera;
      }
      throw const PairingStorageFailure();
    } on PlatformException catch (_, stack) {
      _failed('read', stage, clock, 'platform', stack);
      throw const PairingStorageFailure();
    } on MissingPluginException catch (_, stack) {
      _failed('read', stage, clock, 'plugin_missing', stack);
      throw const PairingStorageFailure();
    } on FormatException catch (_, stack) {
      _failed('read', stage, clock, 'invalid_json', stack);
      throw const PairingStorageFailure();
    } on PairingStorageFailure catch (_, stack) {
      _failed('read', stage, clock, 'invalid_record', stack);
      rethrow;
    } on Object catch (_, stack) {
      _failed('read', stage, clock, 'unexpected', stack);
      rethrow;
    }
  }

  @override
  Future<void> save(RememberedCamera camera) async {
    final clock = Stopwatch()..start();
    var stage = 'write';
    _log.emit(LogLevel.info, 'storage.save.started', stage: stage);
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({
          'version': 1,
          'address': camera.address,
          'addressType': camera.addressType,
          'protocol': camera.protocol,
          'referenceId': camera.referenceId,
          'token': camera.token,
        }),
      );
      stage = 'verify';
      // The Linux plugin discards libsecret's write result boolean.
      final saved = await read();
      if (saved == null ||
          saved.address != camera.address ||
          saved.addressType != camera.addressType ||
          saved.protocol != camera.protocol ||
          saved.referenceId != camera.referenceId ||
          saved.token != camera.token) {
        throw const PairingStorageFailure();
      }
      _log.emit(
        LogLevel.info,
        'storage.save.succeeded',
        stage: stage,
        elapsed: clock.elapsed,
      );
    } on PlatformException catch (_, stack) {
      _failed('save', stage, clock, 'platform', stack);
      throw const PairingStorageFailure();
    } on MissingPluginException catch (_, stack) {
      _failed('save', stage, clock, 'plugin_missing', stack);
      throw const PairingStorageFailure();
    } on PairingStorageFailure catch (_, stack) {
      _failed('save', stage, clock, 'verification', stack);
      rethrow;
    } on Object catch (_, stack) {
      _failed('save', stage, clock, 'unexpected', stack);
      rethrow;
    }
  }

  void _failed(
    String operation,
    String stage,
    Stopwatch clock,
    String code,
    StackTrace stack,
  ) {
    _log.emit(
      LogLevel.error,
      'storage.$operation.failed',
      stage: stage,
      elapsed: clock.elapsed,
      code: code,
      stackTrace: stack,
    );
  }
}
