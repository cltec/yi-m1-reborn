import 'dart:async';

import 'camera_connection.dart';
import 'camera_photos.dart';
import 'diagnostics.dart';

class LoadGallery {
  LoadGallery({
    required this.connection,
    required this.photos,
    this.log = const AppLog(),
  });
  final CameraConnection connection;
  final CameraPhotos photos;
  final AppLog log;

  ListingAttempt? _attempt;
  Completer<void>? _settled;

  Future<List<CameraPhoto>> load() async {
    final clock = Stopwatch()..start();
    log.emit(LogLevel.info, 'gallery.loading');
    try {
      final result = await _run(clock);
      log.emit(LogLevel.info, 'gallery.loaded', elapsed: clock.elapsed);
      return result;
    } on PhotoListingFailure catch (_, stack) {
      log.emit(
        LogLevel.error,
        'gallery.failed',
        elapsed: clock.elapsed,
        code: 'managed_listing_failure',
        stackTrace: stack,
      );
      rethrow;
    } on ListingCancelled {
      log.emit(LogLevel.info, 'gallery.cancelled', elapsed: clock.elapsed);
      rethrow;
    } catch (error, stack) {
      log.emit(
        LogLevel.error,
        'gallery.unexpected',
        elapsed: clock.elapsed,
        code: error.runtimeType.toString(),
        stackTrace: stack,
      );
      rethrow;
    }
  }

  Future<List<CameraPhoto>> _run(Stopwatch clock) async {
    if (_attempt != null) {
      throw const PhotoListingFailure('A photo listing is already running.');
    }
    final attempt = _attempt = ListingAttempt();
    final settled = _settled = Completer<void>();
    try {
      return await _load(attempt, clock);
    } finally {
      _attempt = null;
      _settled = null;
      settled.complete();
    }
  }

  Future<List<CameraPhoto>> _load(
    ListingAttempt attempt,
    Stopwatch clock,
  ) async {
    final session = connection.verifiedSession;
    if (!connection.connected || session == null || !session.isActive) {
      throw const PhotoListingFailure(
        'Connect to the camera before loading photos.',
      );
    }
    var lost = false;
    unawaited(
      session.lost.then((_) {
        if (!identical(_attempt, attempt)) return;
        lost = true;
        attempt.cancel();
      }),
    );
    late List<CameraPhoto> items;
    try {
      log.emit(
        LogLevel.info,
        'gallery.stage',
        stage: 'listing',
        elapsed: clock.elapsed,
      );
      items = await photos.listPhotos(session, attempt);
    } on ListingCancelled {
      if (lost) {
        throw const PhotoListingFailure(
          'The camera connection was lost. Select Retry.',
        );
      }
      rethrow;
    }
    if (lost ||
        !connection.connected ||
        !session.isActive ||
        !identical(connection.verifiedSession, session)) {
      throw const PhotoListingFailure(
        'The camera connection was lost. Select Retry.',
      );
    }
    attempt.check();
    final identities = <String>{};
    for (final photo in items) {
      if (photo.id.isEmpty ||
          photo.filename.isEmpty ||
          !identities.add(photo.id)) {
        throw const PhotoListingFailure(
          'The camera photo listing is malformed. Select Retry.',
        );
      }
    }
    log.emit(
      LogLevel.info,
      'gallery.stage',
      stage: 'sorting',
      elapsed: clock.elapsed,
    );
    return List.unmodifiable(items.toList()..sort(_comparePhotos));
  }

  static int _comparePhotos(CameraPhoto a, CameraPhoto b) {
    final aTime = a.timestamp;
    final bTime = b.timestamp;
    if (aTime != null && bTime != null) {
      final timeOrder = bTime.compareTo(aTime);
      if (timeOrder != 0) return timeOrder;
    } else if (aTime != null) {
      return -1;
    } else if (bTime != null) {
      return 1;
    }
    final nameOrder = a.filename.compareTo(b.filename);
    return nameOrder != 0 ? nameOrder : a.id.compareTo(b.id);
  }

  Future<void> cancel() async {
    final settled = _settled;
    _attempt?.cancel();
    await settled?.future;
  }
}
