import 'dart:async';

import 'camera_discovery.dart';
import 'diagnostics.dart';
import 'camera_network.dart';
import 'camera_pairing.dart';

enum PairingStage {
  storage,
  cameraApproval,
  saving,
  session,
  wifi,
  verification,
}

class PairCamera {
  PairCamera({
    required this.pairing,
    required this.store,
    this.network,
    this.reachability,
    this.log = const AppLog(),
  }) : assert((network == null) == (reachability == null));
  final AppLog log;
  PairingStage? _stage;
  Stopwatch? _clock;
  final CameraPairing pairing;
  final PairingStore store;
  final CameraNetwork? network;
  final CameraReachability? reachability;
  CameraNetworkSession? _networkSession;
  bool get includesNetwork => network != null;
  bool get connected => _networkSession?.isActive == true;
  Future<void>? get connectionLost => _networkSession?.lost;
  Future<void>? get connectionEnded => _networkSession?.ended;
  PairingAttempt? _attempt;
  RememberedCamera? _pendingSave;

  PairingAttempt _begin() {
    if (_attempt != null || _networkSession != null) {
      throw const PairingFailure(
        'A camera connection attempt is already running.',
      );
    }
    _clock = Stopwatch()..start();
    _stage = null;
    log.emit(LogLevel.info, 'connection.started');
    return _attempt = PairingAttempt();
  }

  void _progress(PairingStage stage, void Function(PairingStage)? callback) {
    _stage = stage;
    log.emit(
      LogLevel.info,
      'connection.stage',
      stage: stage.name,
      elapsed: _clock?.elapsed,
    );
    callback?.call(stage);
  }

  void _failure(String code, StackTrace stack) {
    log.emit(
      LogLevel.error,
      'connection.failed',
      stage: _stage?.name,
      elapsed: _clock?.elapsed,
      code: code,
      stackTrace: stack,
    );
  }

  void _success(String outcome) {
    log.emit(LogLevel.info, outcome, elapsed: _clock?.elapsed);
  }

  Future<bool> resumeRemembered({
    void Function(PairingStage)? onProgress,
  }) async {
    final attempt = _begin();
    try {
      _progress(PairingStage.storage, onProgress);
      var camera = await attempt.wait(store.read());
      final pending = _pendingSave;
      if (pending != null) {
        _progress(PairingStage.saving, onProgress);
        await attempt.wait(store.save(pending));
        _pendingSave = null;
        camera = pending;
      }
      if (camera == null) {
        _success('connection.no_remembered_pairing');
        return false;
      }
      _progress(PairingStage.session, onProgress);
      final credentials = await pairing.resume(camera, attempt);
      await _connect(credentials, attempt, onProgress);
      attempt.check();
      _success('connection.ready');
      return true;
    } on PairingFailure catch (_, stack) {
      _failure('managed_connection_failure', stack);
      rethrow;
    } on PairingStorageFailure catch (_, stack) {
      _failure('storage_failure', stack);
      throw const PairingFailure(
        'Pairing storage is unavailable. Unlock the keyring and select Retry.',
      );
    } catch (error, stack) {
      // Observe unexpected faults without converting them to a managed failure.
      log.emit(
        LogLevel.error,
        'connection.unexpected',
        stage: _stage?.name,
        elapsed: _clock?.elapsed,
        code: error.runtimeType.toString(),
        stackTrace: stack,
      );
      rethrow;
    } finally {
      attempt.cancel();
      _attempt = null;
    }
  }

  Future<void> pair(
    DiscoveredCamera camera, {
    void Function(PairingStage)? onProgress,
  }) async {
    final attempt = _begin();
    try {
      _progress(PairingStage.storage, onProgress);
      var existing = await attempt.wait(store.read());
      final pending = _pendingSave;
      if (pending != null) {
        _progress(PairingStage.saving, onProgress);
        await attempt.wait(store.save(pending));
        _pendingSave = null;
        existing = pending;
      }
      if (existing != null) {
        _progress(PairingStage.session, onProgress);
        final credentials = await pairing.resume(existing, attempt);
        await _connect(credentials, attempt, onProgress);
        attempt.check();
        _success('connection.ready');
        return;
      }
      _progress(PairingStage.cameraApproval, onProgress);
      final remembered = await pairing.pair(camera, attempt);
      _pendingSave = remembered;
      attempt.check();
      _progress(PairingStage.saving, onProgress);
      await attempt.wait(store.save(remembered));
      _pendingSave = null;
      _progress(PairingStage.session, onProgress);
      final credentials = await pairing.resume(remembered, attempt);
      await _connect(credentials, attempt, onProgress);
      attempt.check();
      _success('connection.ready');
    } on PairingFailure catch (_, stack) {
      _failure('managed_connection_failure', stack);
      rethrow;
    } on PairingStorageFailure catch (_, stack) {
      _failure('storage_failure', stack);
      throw const PairingFailure(
        'Unable to save pairing in the keyring. Select Retry; pairing will not be repeated automatically.',
      );
    } catch (error, stack) {
      // Observe unexpected faults without converting them to a managed failure.
      log.emit(
        LogLevel.error,
        'connection.unexpected',
        stage: _stage?.name,
        elapsed: _clock?.elapsed,
        code: error.runtimeType.toString(),
        stackTrace: stack,
      );
      rethrow;
    } finally {
      attempt.cancel();
      _attempt = null;
    }
  }

  Future<void> _connect(
    CameraWifiCredentials credentials,
    PairingAttempt attempt,
    void Function(PairingStage)? onProgress,
  ) async {
    attempt.check();
    final network = this.network;
    if (network == null) return;
    _progress(PairingStage.wifi, onProgress);
    final session = await network.join(credentials, attempt);
    var ended = false;
    unawaited(session.ended.then((_) => ended = true));
    var verified = false;
    try {
      attempt.check();
      _progress(PairingStage.verification, onProgress);
      await reachability!.verify(session.localAddress, attempt);
      attempt.check();
      if (ended || !session.isActive) {
        throw const PairingFailure(
          'Camera network connection ended. Select Retry.',
        );
      }
      _networkSession = session;
      verified = true;
      unawaited(
        session.lost.then((_) {
          log.emit(
            LogLevel.warning,
            'connection.lost',
            elapsed: _clock?.elapsed,
          );
        }),
      );
      unawaited(
        session.ended.then((_) {
          if (identical(_networkSession, session)) _networkSession = null;
        }),
      );
    } finally {
      if (!verified) {
        try {
          await session.close();
        } catch (error, stack) {
          // A failure is already propagating; keep it primary and report cleanup.
          log.emit(
            LogLevel.error,
            'connection.cleanup_failed',
            code: error.runtimeType.toString(),
            stackTrace: stack,
          );
        }
      }
    }
  }

  Future<void> cancel() async {
    _attempt?.cancel();
    final session = _networkSession;
    if (session != null) {
      await session.close();
      if (identical(_networkSession, session)) _networkSession = null;
    }
  }
}
