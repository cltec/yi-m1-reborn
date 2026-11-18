import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/application/camera_connection.dart';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/application/camera_photos.dart';
import 'package:yi_m1_reborn/application/camera_network.dart';
import 'package:yi_m1_reborn/application/load_gallery.dart';
import 'package:yi_m1_reborn/application/diagnostics.dart';

void main() {
  test(
    'L4: missing identity or filename is malformed photo metadata',
    () async {
      for (final photo in [
        const CameraPhoto(id: '', filename: 'sample.JPG'),
        const CameraPhoto(id: 'file', filename: ''),
      ]) {
        final gallery = LoadGallery(
          connection: ConnectedCamera(),
          photos: SamplePhotos([photo]),
        );
        await expectLater(gallery.load(), throwsA(isA<PhotoListingFailure>()));
      }
    },
  );

  test(
    'Successful loading logs safe stages and outcome without photo metadata',
    () async {
      final events = <LogEvent>[];
      final gallery = LoadGallery(
        connection: ConnectedCamera(),
        photos: SamplePhotos([
          CameraPhoto(
            id: 'private-id',
            filename: 'private.JPG',
            timestamp: DateTime.utc(2026),
          ),
        ]),
        log: AppLog(sink: events.add),
      );

      await gallery.load();

      expect(events.first.event, 'gallery.loading');
      expect(
        events
            .where((event) => event.event == 'gallery.stage')
            .map((event) => event.stage),
        containsAllInOrder(['listing', 'sorting']),
      );
      expect(events.last.event, 'gallery.loaded');
      expect(events.last.level, LogLevel.info);
      expect(events.last.elapsed, isNotNull);
      final diagnosticText = events
          .map((event) => [event.event, event.stage, event.code].join(' '))
          .join(' ');
      expect(diagnosticText, isNot(contains('private')));
      expect(diagnosticText, isNot(contains('2026')));
    },
  );

  test(
    'Unexpected adapter faults retain identity and stack without logging payloads',
    () async {
      final events = <LogEvent>[];
      final error = StateError('private photo payload');
      final gallery = LoadGallery(
        connection: ConnectedCamera(),
        photos: FailingPhotos(error),
        log: AppLog(sink: events.add),
      );

      await expectLater(gallery.load(), throwsA(same(error)));
      final event = events.singleWhere(
        (event) => event.event == 'gallery.unexpected',
      );
      expect(event.level, LogLevel.error);
      expect(event.code, 'StateError');
      expect(event.stackTrace, isNotNull);
      expect(event.elapsed, isNotNull);
      expect(
        events
            .map((event) => [event.event, event.stage, event.code].join(' '))
            .join(' '),
        isNot(contains('private photo payload')),
      );
    },
  );

  test(
    'Managed listing failure is logged safely and rethrown without automatic retry',
    () async {
      final events = <LogEvent>[];
      const failure = PhotoListingFailure(
        'private filename path identifier timestamp',
      );
      final photos = FailingPhotos(failure);
      final gallery = LoadGallery(
        connection: ConnectedCamera(),
        photos: photos,
        log: AppLog(sink: events.add),
      );

      await expectLater(gallery.load(), throwsA(same(failure)));
      expect(photos.calls, 1);
      expect(events.first.event, 'gallery.loading');
      final event = events.singleWhere(
        (event) => event.event == 'gallery.failed',
      );
      expect(event.level, LogLevel.error);
      expect(event.elapsed, isNotNull);
      expect(event.stackTrace, isNotNull);
      expect(event.code, 'managed_listing_failure');
      expect(
        events
            .map((event) => [event.event, event.stage, event.code].join(' '))
            .join(' '),
        isNot(contains(failure.message)),
      );
    },
  );

  test(
    'An inactive, disconnected or replaced session cannot return a usable catalog',
    () async {
      for (final change in <void Function(ConnectedCamera)>[
        (connection) => connection.connected = false,
        (connection) =>
            (connection.verifiedSession! as SampleSession).isActive = false,
        (connection) => connection.verifiedSession = SampleSession(),
      ]) {
        final connection = ConnectedCamera();
        final photos = PendingPhotos();
        final gallery = LoadGallery(connection: connection, photos: photos);
        final loading = gallery.load();
        final failed = expectLater(
          loading,
          throwsA(isA<PhotoListingFailure>()),
        );
        await photos.started.future;
        change(connection);
        photos.release.complete([]);
        await failed;
      }
    },
  );

  test(
    'Session-loss cancellation from an adapter becomes a listing failure',
    () async {
      final connection = ConnectedCamera();
      final photos = CancellablePhotos();
      final gallery = LoadGallery(connection: connection, photos: photos);
      final failed = expectLater(
        gallery.load(),
        throwsA(isA<PhotoListingFailure>()),
      );
      await photos.started.future;
      (connection.verifiedSession! as SampleSession).loss.complete();
      await failed;
      expect(photos.settled, isTrue);
    },
  );

  test(
    'Session loss cancels listing and cannot publish stale results while cleanup waits',
    () async {
      final connection = ConnectedCamera();
      final session = connection.verifiedSession! as SampleSession;
      final photos = PendingPhotos();
      final gallery = LoadGallery(connection: connection, photos: photos);
      final loading = gallery.load();
      final failed = expectLater(loading, throwsA(isA<PhotoListingFailure>()));
      await photos.started.future;
      session.loss.complete();
      try {
        await Future<void>.delayed(Duration.zero);
        expect(photos.attempt.cancelled, isTrue);
        await expectLater(gallery.load(), throwsA(isA<PhotoListingFailure>()));
      } finally {
        photos.release.complete([]);
      }
      await failed;
    },
  );

  test(
    'Cancellation reaches the adapter and waits for settlement before another load',
    () async {
      final events = <LogEvent>[];
      final photos = PendingPhotos();
      final gallery = LoadGallery(
        connection: ConnectedCamera(),
        photos: photos,
        log: AppLog(sink: events.add),
      );
      final loading = gallery.load();
      final cancelledLoad = expectLater(
        loading,
        throwsA(isA<ListingCancelled>()),
      );
      await photos.started.future;
      var cancellationSettled = false;
      final cancelling = gallery.cancel().then(
        (_) => cancellationSettled = true,
      );
      try {
        await Future<void>.delayed(Duration.zero);
        expect(photos.attempt.cancelled, isTrue);
        expect(cancellationSettled, isFalse);
        await expectLater(gallery.load(), throwsA(isA<PhotoListingFailure>()));
      } finally {
        photos.release.complete([
          const CameraPhoto(id: 'late', filename: 'late.JPG'),
        ]);
      }
      await cancelledLoad;
      await cancelling;
      expect(cancellationSettled, isTrue);
      final cancellation = events.singleWhere(
        (event) => event.event == 'gallery.cancelled',
      );
      expect(cancellation.level, LogLevel.info);
      expect(cancellation.elapsed, isNotNull);
      expect(
        events.any((event) => event.event == 'gallery.unexpected'),
        isFalse,
      );
      expect((await gallery.load()).single.id, 'late');
      await gallery.cancel();
    },
  );

  test(
    'L4: another load cannot start until the current adapter operation settles',
    () async {
      final photos = PendingPhotos();
      final gallery = LoadGallery(
        connection: ConnectedCamera(),
        photos: photos,
      );
      final loading = gallery.load();
      await photos.started.future;

      await expectLater(gallery.load(), throwsA(isA<PhotoListingFailure>()));
      expect(photos.calls, 1);

      photos.release.complete([]);
      expect(await loading, isEmpty);
      expect(await gallery.load(), isEmpty);
      expect(photos.calls, 2);
    },
  );

  test(
    'L4: duplicate file identity is malformed, never a partial successful catalog',
    () async {
      final photos = SamplePhotos([
        const CameraPhoto(id: 'same-id', filename: 'one.JPG'),
        const CameraPhoto(id: 'same-id', filename: 'two.DNG'),
      ]);
      final gallery = LoadGallery(
        connection: ConnectedCamera(),
        photos: photos,
      );

      await expectLater(gallery.load(), throwsA(isA<PhotoListingFailure>()));

      photos.items.removeLast();
      expect((await gallery.load()).single.filename, 'one.JPG');
      expect(photos.calls, 2);
    },
  );

  test(
    'L4: listing requires a verified active connection before reading photos',
    () async {
      final connection = ConnectedCamera()..connected = false;
      final photos = SamplePhotos([]);
      final gallery = LoadGallery(connection: connection, photos: photos);

      await expectLater(gallery.load(), throwsA(isA<PhotoListingFailure>()));
      expect(photos.calls, 0);

      connection.connected = true;
      connection.verifiedSession = null;
      await expectLater(gallery.load(), throwsA(isA<PhotoListingFailure>()));
      expect(photos.calls, 0);

      connection.verifiedSession = SampleSession()..isActive = false;
      await expectLater(gallery.load(), throwsA(isA<PhotoListingFailure>()));
      expect(photos.calls, 0);
    },
  );

  test(
    'L3: successful empty catalog is immutable and independent of adapter storage',
    () async {
      final items = <CameraPhoto>[];
      final gallery = LoadGallery(
        connection: ConnectedCamera(),
        photos: SamplePhotos(items),
      );
      final result = await gallery.load();

      expect(result, isEmpty);
      expect(
        () => result.add(const CameraPhoto(id: 'x', filename: 'x.JPG')),
        throwsUnsupportedError,
      );
      items.add(const CameraPhoto(id: 'later', filename: 'later.JPG'));
      expect(result, isEmpty);
    },
  );

  test(
    'L2: complete photo metadata sorts newest first with deterministic ties',
    () async {
      final newer = DateTime.utc(2026, 11, 18);
      final older = DateTime.utc(2026, 11, 17);
      final items = [
        const CameraPhoto(id: 'u-z', filename: 'z.JPG'),
        CameraPhoto(id: 'old', filename: 'a.JPG', timestamp: older),
        CameraPhoto(id: 'same-b', filename: 'b.JPG', timestamp: newer),
        const CameraPhoto(id: 'u-b', filename: 'a.JPG'),
        CameraPhoto(id: 'raw', filename: 'a.DNG', timestamp: newer),
        CameraPhoto(id: 'same-a', filename: 'b.JPG', timestamp: newer),
        const CameraPhoto(id: 'u-a', filename: 'a.JPG'),
        const CameraPhoto(id: 'no-extension', filename: 'photo'),
      ];
      final gallery = LoadGallery(
        connection: ConnectedCamera(),
        photos: SamplePhotos(items),
      );

      final result = await gallery.load();

      expect(result.map((photo) => photo.id), [
        'raw',
        'same-a',
        'same-b',
        'old',
        'u-a',
        'u-b',
        'no-extension',
        'u-z',
      ]);
      expect(items.first.id, 'u-z');
    },
  );

  test(
    'L1: verified connection loads photo metadata without connecting again',
    () async {
      const photo = CameraPhoto(id: 'file-one', filename: 'sample.JPG');
      final connection = ConnectedCamera();
      final photos = SamplePhotos([photo]);
      final gallery = LoadGallery(connection: connection, photos: photos);

      expect(photos.calls, 0);
      expect(await gallery.load(), [same(photo)]);
      expect(photos.calls, 1);
    },
  );
}

class ConnectedCamera implements CameraConnection {
  @override
  bool connected = true;
  @override
  CameraNetworkSession? verifiedSession = SampleSession();
  @override
  bool get includesNetwork => true;
  @override
  Future<void>? get connectionLost => verifiedSession?.lost;
  @override
  Future<void>? get connectionEnded => null;
  @override
  Future<bool> resumeRemembered({void Function(PairingStage)? onProgress}) =>
      throw StateError('Listing must not connect.');
  @override
  Future<void> pair(
    DiscoveredCamera camera, {
    void Function(PairingStage)? onProgress,
  }) => throw StateError('Listing must not pair.');
  @override
  Future<void> cancel() =>
      throw StateError('Listing does not own the connection.');
}

class SamplePhotos implements CameraPhotos {
  SamplePhotos(this.items);
  final List<CameraPhoto> items;
  int calls = 0;
  @override
  Future<List<CameraPhoto>> listPhotos(
    CameraNetworkSession session,
    ListingAttempt attempt,
  ) async {
    calls++;
    return items;
  }
}

class SampleSession implements CameraNetworkSession {
  @override
  bool isActive = true;
  final loss = Completer<void>();
  @override
  String get localAddress => '192.0.2.1';
  @override
  Future<void> get lost => loss.future;
  @override
  Future<void> get ended => loss.future;
  @override
  Future<void> close() => throw StateError('Listing does not own the session.');
}

class PendingPhotos implements CameraPhotos {
  final started = Completer<void>();
  final release = Completer<List<CameraPhoto>>();
  late ListingAttempt attempt;
  int calls = 0;
  @override
  Future<List<CameraPhoto>> listPhotos(
    CameraNetworkSession session,
    ListingAttempt attempt,
  ) async {
    calls++;
    this.attempt = attempt;
    if (!started.isCompleted) started.complete();
    return release.future;
  }
}

class CancellablePhotos implements CameraPhotos {
  final started = Completer<void>();
  bool settled = false;
  @override
  Future<List<CameraPhoto>> listPhotos(
    CameraNetworkSession session,
    ListingAttempt attempt,
  ) async {
    started.complete();
    await attempt.cancellation;
    settled = true;
    attempt.check();
    return [];
  }
}

class FailingPhotos implements CameraPhotos {
  FailingPhotos(this.error);
  final Object error;
  int calls = 0;
  @override
  Future<List<CameraPhoto>> listPhotos(
    CameraNetworkSession session,
    ListingAttempt attempt,
  ) async {
    calls++;
    throw error;
  }
}
