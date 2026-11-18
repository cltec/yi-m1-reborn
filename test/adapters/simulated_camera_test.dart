import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import 'package:yi_m1_reborn/adapters/simulated_camera.dart';
import 'package:yi_m1_reborn/application/camera_photos.dart';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/application/camera_connection.dart';
import 'package:yi_m1_reborn/application/diagnostics.dart';

void main() {
  test(
    'Loss during loading settles with failure, never stale success',
    () async {
      final camera = SimulatedCamera(catalog: SimulatedCatalog.loading);
      await camera.resumeRemembered();
      final session = camera.verifiedSession!;
      final result = camera.listPhotos(session, ListingAttempt());
      final assertion = expectLater(
        result,
        throwsA(isA<PhotoListingFailure>()),
      );
      await Future<void>.value();
      await session.close();
      await assertion;
      expect(camera.connected, isFalse);
      await camera.cancel();
    },
  );

  test('Already-cancelled listing cannot return any catalog mode', () async {
    for (final catalog in SimulatedCatalog.values) {
      final camera = SimulatedCamera(catalog: catalog);
      await camera.resumeRemembered();
      final attempt = ListingAttempt()..cancel();
      await expectLater(
        camera.listPhotos(camera.verifiedSession!, attempt),
        throwsA(isA<ListingCancelled>()),
      );
      await camera.cancel();
    }
  });

  test('Pair is unsupported and never creates a session', () async {
    final camera = SimulatedCamera();
    await expectLater(
      camera.pair(
        const DiscoveredCamera(id: 'synthetic-only', name: 'Synthetic camera'),
      ),
      throwsStateError,
    );
    expect(camera.connected, isFalse);
    expect(camera.verifiedSession, isNull);
    await camera.cancel();
  });

  test(
    'Unexpected setup callback failures propagate with safe diagnostic context',
    () async {
      final events = <LogEvent>[];
      final camera = SimulatedCamera(log: AppLog(sink: events.add));
      final fault = StateError('private-test-payload');
      await expectLater(
        camera.resumeRemembered(onProgress: (_) => throw fault),
        throwsA(same(fault)),
      );
      final event = events.singleWhere(
        (e) => e.event == 'simulated.connection.unexpected',
      );
      expect(event.level, LogLevel.error);
      expect(event.code, 'StateError');
      expect(event.stage, 'storage');
      expect(event.stackTrace, isNotNull);
      expect(event.elapsed, isNotNull);
      expect(
        events.map((e) => [e.event, e.stage, e.code].join(' ')).join(' '),
        isNot(contains('private-test-payload')),
      );
      expect(camera.connected, isFalse);
      expect(await camera.resumeRemembered(), isTrue);
      await camera.cancel();
    },
  );

  test(
    'Unexpected listing faults stay unexpected and are reported without raw messages',
    () async {
      final events = <LogEvent>[];
      final camera = SimulatedCamera(
        catalog: SimulatedCatalog.unexpected,
        log: AppLog(sink: events.add),
      );
      await camera.resumeRemembered();
      await expectLater(
        camera.listPhotos(camera.verifiedSession!, ListingAttempt()),
        throwsStateError,
      );
      final failure = events.singleWhere(
        (e) => e.event == 'simulated.listing.unexpected',
      );
      expect(failure.level, LogLevel.error);
      expect(failure.code, 'StateError');
      expect(failure.elapsed, isNotNull);
      expect(failure.stackTrace, isNotNull);
      expect(
        events.where(
          (e) =>
              e.event == 'simulated.listing.failed' ||
              e.event == 'simulated.listing.ready',
        ),
        isEmpty,
      );
      await camera.cancel();
    },
  );

  test(
    'Listing rejects foreign and ended sessions instead of returning stale files',
    () async {
      final camera = SimulatedCamera();
      final other = SimulatedCamera();
      await camera.resumeRemembered();
      await other.resumeRemembered();
      await expectLater(
        camera.listPhotos(other.verifiedSession!, ListingAttempt()),
        throwsA(isA<PhotoListingFailure>()),
      );
      final session = camera.verifiedSession!;
      await session.close();
      expect(camera.verifiedSession, isNull);
      await expectLater(
        camera.listPhotos(session, ListingAttempt()),
        throwsA(isA<PhotoListingFailure>()),
      );
      await camera.cancel();
      await other.cancel();
    },
  );

  test(
    'Closing the simulated camera cancels and settles its pending listing',
    () async {
      final camera = SimulatedCamera(catalog: SimulatedCatalog.loading);
      await camera.resumeRemembered();
      final attempt = ListingAttempt();
      var settled = false;
      final result = camera.listPhotos(camera.verifiedSession!, attempt);
      final assertion = expectLater(
        result.whenComplete(() => settled = true),
        throwsA(isA<ListingCancelled>()),
      );
      await camera.cancel();
      final settledOnClose = settled;
      attempt.cancel();
      await assertion;
      expect(settledOnClose, isTrue);
      expect(camera.connected, isFalse);
    },
  );

  test(
    'L6: loading remains pending until its attempt is cancelled and settles',
    () async {
      final events = <LogEvent>[];
      final started = Completer<void>();
      final camera = SimulatedCamera(
        catalog: SimulatedCatalog.loading,
        log: AppLog(
          sink: (event) {
            events.add(event);
            if (event.event == 'simulated.listing.started') started.complete();
          },
        ),
      );
      await camera.resumeRemembered();
      final attempt = ListingAttempt();
      var settled = false;
      final result = camera.listPhotos(camera.verifiedSession!, attempt);
      final assertion = expectLater(
        result.whenComplete(() => settled = true),
        throwsA(isA<ListingCancelled>()),
      );
      await started.future;
      await Future<void>.value();
      expect(settled, isFalse);
      attempt.cancel();
      await assertion;
      expect(settled, isTrue);
      expect(
        events
            .singleWhere((e) => e.event == 'simulated.listing.cancelled')
            .level,
        LogLevel.warning,
      );
      expect(
        events.where((e) => e.event == 'simulated.listing.ready'),
        isEmpty,
      );
      await camera.cancel();
    },
  );

  test(
    'L4: managed failure logs safely and only a manual second list succeeds',
    () async {
      final events = <LogEvent>[];
      final camera = SimulatedCamera(
        catalog: SimulatedCatalog.error,
        log: AppLog(sink: events.add),
      );
      await camera.resumeRemembered();
      final session = camera.verifiedSession!;
      await expectLater(
        camera.listPhotos(session, ListingAttempt()),
        throwsA(isA<PhotoListingFailure>()),
      );
      expect(
        events.where((e) => e.event == 'simulated.listing.started').length,
        1,
      );
      final failure = events.singleWhere(
        (e) => e.event == 'simulated.listing.failed',
      );
      expect(failure.level, LogLevel.error);
      expect(failure.elapsed, isNotNull);
      expect(failure.stackTrace, isNotNull);
      expect(failure.code, 'simulated_listing_failure');
      final photos = await camera.listPhotos(session, ListingAttempt());
      expect(photos, isNotEmpty);
      expect(camera.verifiedSession, same(session));
      final diagnostics = events
          .map((e) => [e.event, e.stage, e.code, e.reason, e.state].join(' '))
          .join(' ');
      for (final photo in photos) {
        expect(diagnostics, isNot(contains(photo.id)));
        expect(diagnostics, isNot(contains(photo.filename)));
      }
      expect(diagnostics, isNot(contains(session.localAddress)));
      await camera.cancel();
    },
  );

  test(
    'L3: empty simulated catalog is a successful complete listing',
    () async {
      final events = <LogEvent>[];
      final camera = SimulatedCamera(
        catalog: SimulatedCatalog.empty,
        log: AppLog(sink: events.add),
      );
      await camera.resumeRemembered();
      expect(
        await camera.listPhotos(camera.verifiedSession!, ListingAttempt()),
        isEmpty,
      );
      expect(
        events.singleWhere((e) => e.event == 'simulated.listing.ready').level,
        LogLevel.info,
      );
      await camera.cancel();
    },
  );

  test('Cancelling setup settles it without a late verified session', () async {
    final events = <LogEvent>[];
    final camera = SimulatedCamera(log: AppLog(sink: events.add));
    Future<void>? closing;
    final result = camera.resumeRemembered(
      onProgress: (stage) {
        if (stage == PairingStage.wifi) closing = camera.cancel();
      },
    );
    await expectLater(result, throwsA(isA<PairingFailure>()));
    await closing;
    expect(camera.connected, isFalse);
    expect(camera.verifiedSession, isNull);
    expect(
      events.where((e) => e.event == 'simulated.connection.ready'),
      isEmpty,
    );
    expect(
      events
          .singleWhere((e) => e.event == 'simulated.connection.cancelled')
          .level,
      LogLevel.warning,
    );
    expect(await camera.resumeRemembered(), isTrue);
    final session = camera.verifiedSession!;
    final lost = camera.connectionLost!;
    final ended = camera.connectionEnded!;
    await camera.cancel();
    await lost;
    await ended;
    expect(session.isActive, isFalse);
    expect(camera.connected, isFalse);
    expect(camera.verifiedSession, isNull);
    await camera.cancel();
  });

  test(
    'Remembered simulation reports safe stages and verified session only at readiness',
    () async {
      final events = <LogEvent>[];
      final stages = <PairingStage>[];
      final camera = SimulatedCamera(log: AppLog(sink: events.add));
      await camera.resumeRemembered(
        onProgress: (stage) {
          expect(camera.verifiedSession, isNull);
          stages.add(stage);
        },
      );
      expect(stages, [
        PairingStage.storage,
        PairingStage.session,
        PairingStage.wifi,
        PairingStage.verification,
      ]);
      expect(events.first.event, 'simulated.connection.started');
      expect(events.last.event, 'simulated.connection.ready');
      expect(
        events.every((e) => e.level == LogLevel.info && e.elapsed != null),
        isTrue,
      );
      expect(
        events.where((e) => e.stage != null).map((e) => e.stage),
        stages.map((s) => s.name),
      );
      expect(camera.verifiedSession!.isActive, isTrue);
      await camera.cancel();
    },
  );

  test(
    'L1: remembered simulated connection lists separate synthetic files',
    () async {
      final camera = SimulatedCamera();
      expect(camera.includesNetwork, isTrue);
      expect(camera.connected, isFalse);
      expect(await camera.discover(), isEmpty);
      expect(await camera.resumeRemembered(), isTrue);
      expect(camera.connected, isTrue);

      final photos = await camera.listPhotos(
        camera.verifiedSession!,
        ListingAttempt(),
      );
      expect(photos, isNotEmpty);
      expect(photos.map((p) => p.id).toSet().length, photos.length);
      expect(
        photos.map((p) => p.filename),
        containsAll(['DEMO0001.JPG', 'DEMO0001.DNG']),
      );
      final duplicates = photos.where((p) => p.filename == 'DEMO0001.JPG');
      expect(duplicates.length, 2);
      expect(photos.any((p) => p.timestamp == null), isTrue);
      expect(
        photos
            .where((p) => p.timestamp != null)
            .every((p) => p.timestamp!.isUtc),
        isTrue,
      );
      await camera.cancel();
    },
  );
}
