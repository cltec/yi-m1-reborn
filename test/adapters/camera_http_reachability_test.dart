import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/adapters/camera_http_reachability.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import 'package:yi_m1_reborn/application/diagnostics.dart';

void main() {
  test(
    'Given HTTP success without valid camera status, verification fails',
    () async {
      for (final payload in [
        {'code': 1515, 'data': 'private camera diagnostic'},
        {'code': 200},
        {
          'data': {'batteryLevel': '75', 'SurplusPhotoCnts': '691'},
        },
        {
          'code': 200,
          'data': {'batteryLevel': 'not a number', 'SurplusPhotoCnts': '691'},
        },
        {
          'code': 200,
          'data': {'batteryLevel': '75'},
        },
        ['not status'],
      ]) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final serving = server.first.then((request) async {
          request.response.write(jsonEncode(payload));
          await request.response.close();
        });
        try {
          final adapter = CameraHttpReachability(
            endpoint: Uri.parse('http://127.0.0.1:${server.port}/'),
          );
          await expectLater(
            adapter.verify('127.0.0.1', PairingAttempt()),
            throwsA(
              isA<PairingFailure>().having(
                (failure) => failure.message,
                'message',
                allOf(
                  contains('Camera response'),
                  isNot(contains('private camera diagnostic')),
                ),
              ),
            ),
          );
          await serving;
        } finally {
          await server.close(force: true);
        }
      }
    },
  );

  test(
    'Given redirect, HTTP error, malformed or oversized response, fail without retry',
    () async {
      for (final kind in ['redirect', 'http error', 'malformed', 'oversized']) {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final requests = <HttpRequest>[];
        final subscription = server.listen((request) async {
          requests.add(request);
          if (kind == 'redirect') {
            request.response.statusCode = HttpStatus.found;
            request.response.headers.set('location', '/private?token=secret');
          } else if (kind == 'http error') {
            request.response.statusCode = HttpStatus.serviceUnavailable;
          }
          request.response.write(switch (kind) {
            'malformed' => 'private-invalid-json',
            'oversized' => 'x' * (16 * 1024 + 1),
            _ =>
              '{"code":200,"data":{"batteryLevel":"75","SurplusPhotoCnts":"691"}}',
          });
          await request.response.close();
        });
        try {
          final events = <LogEvent>[];
          await expectLater(
            CameraHttpReachability(
              endpoint: Uri.parse('http://127.0.0.1:${server.port}/'),
              log: AppLog(sink: events.add),
            ).verify('127.0.0.1', PairingAttempt()),
            throwsA(
              isA<PairingFailure>().having(
                (failure) => failure.message,
                'message',
                allOf(
                  contains('Camera response'),
                  isNot(contains('private')),
                  isNot(contains('127.0.0.1')),
                ),
              ),
            ),
          );
          expect(requests, hasLength(1));
          final failure = events.singleWhere(
            (event) => event.event == 'http.verify.failed',
          );
          expect(failure.level, LogLevel.error);
          expect(failure.code, kind == 'malformed' ? 'format' : 'rejected');
          expect(failure.elapsed, isNotNull);
          expect(failure.stackTrace, isNotNull);
          final rendered = events
              .map(
                (event) =>
                    '${event.event} ${event.stage} ${event.code} ${event.stackTrace}',
              )
              .join();
          expect(rendered, isNot(contains('private')));
          expect(rendered, isNot(contains('127.0.0.1')));
        } finally {
          await subscription.cancel();
          await server.close(force: true);
        }
      }
    },
  );

  test(
    'Given cancellation or timeout, close the stalled socket before settling',
    () async {
      for (final cancel in [true, false]) {
        for (final headers in [true, false]) {
          final server = await ServerSocket.bind(
            InternetAddress.loopbackIPv4,
            0,
          );
          final received = Completer<void>();
          final disconnected = Completer<void>();
          final accepted = Completer<Socket>();
          final subscription = server.listen((socket) {
            accepted.complete(socket);
            unawaited(socket.done.catchError((Object _) {}));
            socket.listen(
              (bytes) {
                if (!received.isCompleted) {
                  if (headers) {
                    socket.write(
                      'HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\n{',
                    );
                  }
                  received.complete();
                }
              },
              onDone: () {
                if (!disconnected.isCompleted) disconnected.complete();
              },
              onError: (Object _) {
                if (!disconnected.isCompleted) disconnected.complete();
              },
            );
          });
          final attempt = PairingAttempt(
            limit: Duration(seconds: cancel ? 10 : 1),
          );
          final verification = CameraHttpReachability(
            endpoint: Uri.parse('http://127.0.0.1:${server.port}/'),
          ).verify('127.0.0.1', attempt);
          final expectation = expectLater(
            verification,
            throwsA(isA<PairingFailure>()),
          );
          try {
            await received.future.timeout(const Duration(seconds: 2));
            if (cancel) attempt.cancel();
            await expectation.timeout(const Duration(seconds: 2));
            await disconnected.future.timeout(const Duration(seconds: 1));
          } finally {
            (await accepted.future).destroy();
            await subscription.cancel();
            await server.close();
          }
        }
      }
    },
  );

  test('Given an ended attempt, issue no request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = <HttpRequest>[];
    final subscription = server.listen(requests.add);
    try {
      for (final attempt in [
        PairingAttempt()..cancel(),
        PairingAttempt(limit: Duration.zero),
      ]) {
        await expectLater(
          CameraHttpReachability(
            endpoint: Uri.parse('http://127.0.0.1:${server.port}/'),
          ).verify('127.0.0.1', attempt),
          throwsA(isA<PairingFailure>()),
        );
      }
      expect(requests, isEmpty);
    } finally {
      await subscription.cancel();
      await server.close(force: true);
    }
  });

  test(
    'Given an invalid source or non-local test endpoint, fail before requesting',
    () async {
      for (final addresses in [
        ('not-an-address', 'http://127.0.0.1/'),
        ('::1', 'http://127.0.0.1/'),
        ('0.0.0.0', 'http://127.0.0.1/'),
        ('127.0.0.1', 'http://example.invalid/'),
        ('127.0.0.1', 'http://192.0.2.1/'),
        ('127.0.0.1', 'https://127.0.0.1/'),
      ]) {
        await expectLater(
          CameraHttpReachability(
            endpoint: Uri.parse(addresses.$2),
          ).verify(addresses.$1, PairingAttempt()),
          throwsA(
            isA<PairingFailure>().having(
              (failure) => failure.message,
              'message',
              contains('configuration'),
            ),
          ),
        );
      }
    },
  );

  test(
    'Given a programming error while connecting, preserve the error and stack',
    () async {
      for (final error in [StateError('private address token'), TypeError()]) {
        final events = <LogEvent>[];
        final verification = IOOverrides.runZoned(
          () => CameraHttpReachability(
            endpoint: Uri.parse('http://127.0.0.1/'),
            log: AppLog(sink: events.add),
          ).verify('127.0.0.1', PairingAttempt()),
          socketStartConnect: (host, port, {sourceAddress, sourcePort = 0}) =>
              Future<ConnectionTask<Socket>>.error(error, StackTrace.current),
        );

        await expectLater(verification, throwsA(same(error)));

        final failure = events.firstWhere(
          (event) => event.level == LogLevel.error,
        );
        expect(failure.code, 'unexpected');
        expect(failure.stage, 'connect');
        expect(failure.stackTrace, isNotNull);
        expect(failure.elapsed, isNotNull);
        expect(
          events.map((event) => event.event),
          isNot(contains('http.verify.succeeded')),
        );
      }
    },
  );

  test(
    'Given a socket failure and failing cleanup, retain the managed primary failure',
    () async {
      final events = <LogEvent>[];
      final verification = IOOverrides.runZoned(
        () => CameraHttpReachability(
          endpoint: Uri.parse('http://127.0.0.1/'),
          log: AppLog(sink: events.add),
        ).verify('127.0.0.1', PairingAttempt()),
        socketStartConnect:
            (host, port, {sourceAddress, sourcePort = 0}) async =>
                ConnectionTask.fromSocket(
                  Future<Socket>(
                    () => throw const SocketException('private address token'),
                  ),
                  () => throw StateError('private cleanup token'),
                ),
      );

      await expectLater(verification, throwsA(isA<PairingFailure>()));

      expect(
        events
            .where((event) => event.event == 'http.verify.failed')
            .single
            .code,
        'socket',
      );
      final cleanup = events.firstWhere(
        (event) => event.event == 'http.cleanup.failed',
      );
      expect(cleanup.level, LogLevel.error);
      expect(cleanup.code, 'unexpected');
      expect(cleanup.stackTrace, isNotNull);
      final rendered = events
          .map(
            (event) =>
                '${event.event} ${event.stage} ${event.code} ${event.stackTrace}',
          )
          .join();
      expect(rendered, isNot(contains('private')));
      expect(rendered, isNot(contains('127.0.0.1')));
    },
  );

  test(
    'Given cancellation while creating a connection, cancel the late task',
    () async {
      final entered = Completer<void>();
      final starting = Completer<ConnectionTask<Socket>>();
      final connecting = Completer<Socket>();
      var cancelled = false;
      final attempt = PairingAttempt();
      final verification = IOOverrides.runZoned(
        () => CameraHttpReachability(
          endpoint: Uri.parse('http://127.0.0.1/'),
        ).verify('127.0.0.1', attempt),
        socketStartConnect: (host, port, {sourceAddress, sourcePort = 0}) {
          entered.complete();
          return starting.future;
        },
      );
      final expectation = expectLater(
        verification,
        throwsA(isA<PairingFailure>()),
      );
      await entered.future;
      attempt.cancel();
      starting.complete(
        ConnectionTask.fromSocket(connecting.future, () {
          cancelled = true;
          if (!connecting.isCompleted) {
            connecting.completeError(const SocketException('cancelled'));
          }
        }),
      );
      await expectation.timeout(const Duration(seconds: 1));
      expect(cancelled, isTrue);
    },
  );

  test(
    'Given camera Wi-Fi, status success verifies one source-bound request',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final requests = <HttpRequest>[];
      final serving = server.first.then((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.uri.path, '/');
        expect(jsonDecode(request.uri.queryParameters['data']!), {
          'command': 'GetCameraStatus',
        });
        expect(request.connectionInfo!.remoteAddress.address, '127.0.0.2');
        request.response.write(
          jsonEncode({
            'code': 200,
            'data': {'batteryLevel': '75', 'SurplusPhotoCnts': '691'},
          }),
        );
        await request.response.close();
      });
      final events = <LogEvent>[];
      final adapter = CameraHttpReachability(
        endpoint: Uri.parse('http://127.0.0.1:${server.port}/'),
        log: AppLog(sink: events.add),
      );

      var proxyLookups = 0;
      await HttpOverrides.runZoned(
        () => adapter.verify('127.0.0.2', PairingAttempt()),
        findProxyFromEnvironment: (_, _) {
          proxyLookups++;
          return 'PROXY 127.0.0.1:1';
        },
      );
      expect(proxyLookups, 0);

      await serving;
      expect(requests, hasLength(1));
      expect(events.first.event, 'http.verify.started');
      expect(events.last.event, 'http.verify.succeeded');
      expect(events.last.level, LogLevel.info);
      expect(events.last.elapsed, isNotNull);
      expect(
        events.map((event) => event.stage),
        containsAllInOrder(['connect', 'response', 'validate', 'cleanup']),
      );
      final rendered = events
          .map(
            (event) =>
                '${event.event} ${event.stage} ${event.code} ${event.stackTrace}',
          )
          .join();
      expect(rendered, isNot(contains('127.0.0.')));
      expect(rendered, isNot(contains('GetCameraStatus')));
    },
  );
}
