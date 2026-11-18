import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../application/camera_network.dart';
import '../application/camera_pairing.dart';
import '../application/diagnostics.dart';

/// A read-only M1 status request. Source evidence is not hardware validation.
class CameraHttpReachability implements CameraReachability {
  CameraHttpReachability({Uri? endpoint, AppLog log = const AppLog()})
    : _endpoint = endpoint ?? Uri.parse('http://192.168.0.10/'),
      _log = log;

  final AppLog _log;
  final Uri _endpoint;

  @override
  Future<void> verify(String localAddress, PairingAttempt attempt) async {
    final clock = Stopwatch()..start();
    var stage = 'configuration';
    _log.emit(LogLevel.info, 'http.verify.started', stage: stage);
    void reached(String value) {
      stage = value;
      _log.emit(
        LogLevel.info,
        'http.verify.stage',
        stage: stage,
        elapsed: clock.elapsed,
      );
    }

    void failed(String code, StackTrace stack) {
      _log.emit(
        LogLevel.error,
        'http.verify.failed',
        stage: stage,
        elapsed: clock.elapsed,
        code: code,
        stackTrace: stack,
      );
    }

    HttpClient? client;
    ConnectionTask<Socket>? connection;
    Future<ConnectionTask<Socket>>? starting;
    Socket? socket;
    Future<void>? operation;
    var operationEnded = false;
    var closing = false;
    var primaryFailure = false;
    try {
      attempt.check();
      final source = InternetAddress.tryParse(localAddress);
      final destination = InternetAddress.tryParse(_endpoint.host);
      if (source == null ||
          source.type != InternetAddressType.IPv4 ||
          source.address == '0.0.0.0' ||
          destination == null ||
          destination.type != InternetAddressType.IPv4 ||
          (!destination.isLoopback && destination.address != '192.168.0.10') ||
          _endpoint.scheme != 'http' ||
          _endpoint.path != '/' ||
          _endpoint.userInfo.isNotEmpty ||
          _endpoint.hasQuery ||
          _endpoint.hasFragment) {
        throw const PairingFailure(
          'Camera response configuration is invalid. Select Retry.',
        );
      }
      client = HttpClient()
        ..findProxy = ((_) => 'DIRECT')
        ..autoUncompress = false;
      client.connectionFactory = (uri, proxyHost, proxyPort) async {
        attempt.check();
        reached('connect');
        final pending = Socket.startConnect(
          destination,
          uri.port,
          sourceAddress: source,
        );
        starting = pending;
        final task = await pending;
        connection = task;
        if (closing) {
          task.cancel();
          try {
            (await task.socket).destroy();
          } on SocketException catch (_, stack) {
            _log.emit(
              LogLevel.debug,
              'http.cleanup.aborted',
              stage: 'connect',
              elapsed: clock.elapsed,
              code: 'socket',
              stackTrace: stack,
            );
          }
          throw const PairingFailure(
            'Camera response check ended. Select Retry.',
          );
        }
        return ConnectionTask.fromSocket(
          task.socket.then((connected) {
            socket = connected;
            if (closing) connected.destroy();
            return connected;
          }),
          task.cancel,
        );
      };
      operation = _request(client, attempt, reached).whenComplete(() {
        operationEnded = true;
      });
      await attempt.wait(operation);
    } on PairingFailure catch (_, stack) {
      primaryFailure = true;
      failed('rejected', stack);
      rethrow;
    } on SocketException catch (_, stack) {
      primaryFailure = true;
      failed('socket', stack);
      throw const PairingFailure('Camera response check failed. Select Retry.');
    } on HttpException catch (_, stack) {
      primaryFailure = true;
      failed('http', stack);
      throw const PairingFailure('Camera response check failed. Select Retry.');
    } on FormatException catch (_, stack) {
      primaryFailure = true;
      failed('format', stack);
      throw const PairingFailure('Camera response check failed. Select Retry.');
    } on Object catch (_, stack) {
      primaryFailure = true;
      failed('unexpected', stack);
      rethrow;
    } finally {
      closing = true;
      if (client != null) {
        reached('cleanup');
        Object? cleanupError;
        StackTrace? cleanupStack;
        Future<void> cleanup(FutureOr<void> Function() action) async {
          try {
            await action();
          } on SocketException catch (_, stack) {
            _log.emit(
              LogLevel.warning,
              'http.cleanup.aborted',
              stage: 'cleanup',
              elapsed: clock.elapsed,
              code: 'socket',
              stackTrace: stack,
            );
          } on HttpException catch (_, stack) {
            _log.emit(
              LogLevel.warning,
              'http.cleanup.aborted',
              stage: 'cleanup',
              elapsed: clock.elapsed,
              code: 'http',
              stackTrace: stack,
            );
          } on FormatException catch (_, stack) {
            _log.emit(
              LogLevel.warning,
              'http.cleanup.aborted',
              stage: 'cleanup',
              elapsed: clock.elapsed,
              code: 'format',
              stackTrace: stack,
            );
          } on PairingFailure catch (_, stack) {
            _log.emit(
              LogLevel.debug,
              'http.cleanup.aborted',
              stage: 'cleanup',
              elapsed: clock.elapsed,
              code: 'ended',
              stackTrace: stack,
            );
          } on Object catch (error, stack) {
            _log.emit(
              LogLevel.error,
              'http.cleanup.failed',
              stage: 'cleanup',
              elapsed: clock.elapsed,
              code: 'unexpected',
              stackTrace: stack,
            );
            cleanupError ??= error;
            cleanupStack ??= stack;
          }
        }

        await cleanup(() => connection?.cancel());
        await cleanup(() => socket?.destroy());
        await cleanup(() => client!.close(force: true));
        // A factory may still be creating its cancellable connection task.
        await cleanup(() async {
          final pending = starting;
          if (pending != null) (await pending).cancel();
        });
        await cleanup(() => socket?.destroy());
        // Future.any has observed a settled request already. Only an aborted
        // request still needs settlement before permitting a later attempt.
        if (!operationEnded && operation != null) {
          await cleanup(() => operation!);
        }
        if (!primaryFailure && cleanupError != null) {
          Error.throwWithStackTrace(cleanupError!, cleanupStack!);
        }
      }
    }
    _log.emit(
      LogLevel.info,
      'http.verify.succeeded',
      stage: 'complete',
      elapsed: clock.elapsed,
    );
  }

  Future<void> _request(
    HttpClient client,
    PairingAttempt attempt,
    void Function(String) reached,
  ) async {
    attempt.check();
    final request = await client.getUrl(
      _endpoint.replace(
        queryParameters: {
          'data': jsonEncode({'command': 'GetCameraStatus'}),
        },
      ),
    );
    request.followRedirects = false;
    request.persistentConnection = false;
    attempt.check();
    final response = await request.close();
    reached('response');
    if (response.statusCode != HttpStatus.ok) {
      throw const PairingFailure(
        'Camera response HTTP check failed. Select Retry.',
      );
    }
    reached('body');
    final bytes = <int>[];
    await for (final chunk in response) {
      attempt.check();
      if (bytes.length + chunk.length > 16 * 1024) {
        throw const PairingFailure(
          'Camera response exceeded the status size limit. Select Retry.',
        );
      }
      bytes.addAll(chunk);
    }
    reached('validate');
    final payload = jsonDecode(utf8.decode(bytes));
    if (payload is! Map<String, dynamic> ||
        payload['code'] != 200 ||
        payload['data'] is! Map<String, dynamic>) {
      throw const PairingFailure(
        'Camera response was not a successful status. Select Retry.',
      );
    }
    final data = payload['data'] as Map<String, dynamic>;
    if (data['batteryLevel'] is! String ||
        int.tryParse(data['batteryLevel'] as String) == null ||
        data['SurplusPhotoCnts'] is! String ||
        int.tryParse(data['SurplusPhotoCnts'] as String) == null) {
      throw const PairingFailure(
        'Camera response did not contain valid status. Select Retry.',
      );
    }
  }
}
