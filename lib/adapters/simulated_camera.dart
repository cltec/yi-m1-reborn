import 'dart:async';

import '../application/camera_connection.dart';
import '../application/camera_discovery.dart';
import '../application/camera_network.dart';
import '../application/camera_photos.dart';
import '../application/camera_pairing.dart';
import '../application/diagnostics.dart';

enum SimulatedCatalog { populated, empty, error, loading, unexpected }

/// Offline fixtures only. Construct at the simulated composition root, never
/// alongside real transports or secret storage.
class SimulatedCamera
    implements CameraConnection, CameraPhotos, CameraDiscovery {
  SimulatedCamera({
    this.log = const AppLog(),
    this.catalog = SimulatedCatalog.populated,
  });

  final AppLog log;
  final SimulatedCatalog catalog;
  _SimulatedSession? _session;
  PairingAttempt? _setupAttempt;
  Completer<void>? _setupSettled;
  bool _listingFailed = false;
  final _listings = <Completer<void>, ListingAttempt>{};

  @override
  bool get includesNetwork => true;
  @override
  bool get connected => _session?.isActive == true;
  @override
  CameraNetworkSession? get verifiedSession => connected ? _session : null;
  @override
  Future<void>? get connectionLost => verifiedSession?.lost;
  @override
  Future<void>? get connectionEnded => verifiedSession?.ended;

  @override
  Future<List<DiscoveredCamera>> discover() async => const [];

  @override
  Future<bool> resumeRemembered({
    void Function(PairingStage)? onProgress,
  }) async {
    if (_setupAttempt != null || connected) {
      throw const PairingFailure('A simulated connection is already active.');
    }
    final attempt = _setupAttempt = PairingAttempt();
    final settled = _setupSettled = Completer<void>();
    final clock = Stopwatch()..start();
    PairingStage? currentStage;
    log.emit(
      LogLevel.info,
      'simulated.connection.started',
      elapsed: clock.elapsed,
    );
    try {
      for (final stage in [
        PairingStage.storage,
        PairingStage.session,
        PairingStage.wifi,
        PairingStage.verification,
      ]) {
        currentStage = stage;
        attempt.check();
        log.emit(
          LogLevel.info,
          'simulated.connection.stage',
          stage: stage.name,
          elapsed: clock.elapsed,
        );
        onProgress?.call(stage);
        await Future<void>.value();
        attempt.check();
      }
      _session = _SimulatedSession();
      log.emit(
        LogLevel.info,
        'simulated.connection.ready',
        elapsed: clock.elapsed,
      );
      return true;
    } on PairingFailure catch (_, stack) {
      log.emit(
        LogLevel.warning,
        'simulated.connection.cancelled',
        stage: currentStage?.name,
        elapsed: clock.elapsed,
        stackTrace: stack,
      );
      rethrow;
    } catch (error, stack) {
      log.emit(
        LogLevel.error,
        'simulated.connection.unexpected',
        stage: currentStage?.name,
        elapsed: clock.elapsed,
        code: error.runtimeType.toString(),
        stackTrace: stack,
      );
      rethrow;
    } finally {
      _setupAttempt = null;
      _setupSettled = null;
      settled.complete();
    }
  }

  @override
  Future<void> pair(
    DiscoveredCamera camera, {
    void Function(PairingStage)? onProgress,
  }) async {
    throw StateError('The simulated camera uses remembered setup only.');
  }

  @override
  Future<void> cancel() async {
    _setupAttempt?.cancel();
    await _setupSettled?.future;
    final listings = Map.of(_listings);
    for (final attempt in listings.values) {
      attempt.cancel();
    }
    await Future.wait(listings.keys.map((settled) => settled.future));
    final session = _session;
    if (session != null) {
      final clock = Stopwatch()..start();
      await session.close();
      _session = null;
      log.emit(
        LogLevel.info,
        'simulated.connection.closed',
        elapsed: clock.elapsed,
      );
    }
  }

  @override
  Future<List<CameraPhoto>> listPhotos(
    CameraNetworkSession session,
    ListingAttempt attempt,
  ) async {
    final clock = Stopwatch()..start();
    final settled = Completer<void>();
    _listings[settled] = attempt;
    log.emit(
      LogLevel.info,
      'simulated.listing.started',
      elapsed: clock.elapsed,
    );
    try {
      attempt.check();
      _checkSession(session);
      await Future<void>.value();
      if (catalog == SimulatedCatalog.loading) {
        await Future.any<void>([attempt.cancellation, session.ended]);
      }
      attempt.check();
      _checkSession(session);
      if (catalog == SimulatedCatalog.unexpected) {
        throw StateError('Unexpected simulated listing fault.');
      }
      if (catalog == SimulatedCatalog.error && !_listingFailed) {
        _listingFailed = true;
        throw const PhotoListingFailure(
          'Simulated photo listing failed. Select Retry.',
        );
      }
      final photos = catalog == SimulatedCatalog.empty
          ? <CameraPhoto>[]
          : _populated();
      log.emit(
        LogLevel.info,
        'simulated.listing.ready',
        elapsed: clock.elapsed,
      );
      return photos;
    } on ListingCancelled {
      log.emit(
        LogLevel.warning,
        'simulated.listing.cancelled',
        elapsed: clock.elapsed,
      );
      rethrow;
    } on PhotoListingFailure catch (_, stack) {
      log.emit(
        LogLevel.error,
        'simulated.listing.failed',
        elapsed: clock.elapsed,
        code: 'simulated_listing_failure',
        stackTrace: stack,
      );
      rethrow;
    } catch (error, stack) {
      log.emit(
        LogLevel.error,
        'simulated.listing.unexpected',
        elapsed: clock.elapsed,
        code: error.runtimeType.toString(),
        stackTrace: stack,
      );
      rethrow;
    } finally {
      _listings.remove(settled);
      settled.complete();
    }
  }

  void _checkSession(CameraNetworkSession session) {
    if (!identical(session, _session) || !session.isActive) {
      throw const PhotoListingFailure(
        'Simulated camera connection ended. Select Retry.',
      );
    }
  }

  List<CameraPhoto> _populated() => [
    CameraPhoto(
      id: 'synthetic/folder-a/DEMO0001.JPG',
      filename: 'DEMO0001.JPG',
      timestamp: DateTime.utc(2026, 1, 2, 12),
    ),
    CameraPhoto(
      id: 'synthetic/folder-a/DEMO0001.DNG',
      filename: 'DEMO0001.DNG',
      timestamp: DateTime.utc(2026, 1, 2, 12),
    ),
    const CameraPhoto(
      id: 'synthetic/folder-a/DEMO0003.JPG',
      filename: 'DEMO0003.JPG',
    ),
    CameraPhoto(
      id: 'synthetic/folder-b/DEMO0001.JPG',
      filename: 'DEMO0001.JPG',
      timestamp: DateTime.utc(2026, 1, 3, 12),
    ),
    const CameraPhoto(
      id: 'synthetic/folder-a/DEMO0002.DNG',
      filename: 'DEMO0002.DNG',
    ),
  ];
}

class _SimulatedSession implements CameraNetworkSession {
  final _ended = Completer<void>();
  final _lost = Completer<void>();
  @override
  String get localAddress => '127.0.0.1';
  @override
  bool get isActive => !_ended.isCompleted;
  @override
  Future<void> get lost => _lost.future;
  @override
  Future<void> get ended => _ended.future;
  @override
  Future<void> close() async {
    if (!_lost.isCompleted) _lost.complete();
    if (!_ended.isCompleted) _ended.complete();
  }
}
