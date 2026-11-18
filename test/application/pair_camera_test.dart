import 'dart:async';
import 'package:yi_m1_reborn/application/diagnostics.dart';
import '../../test_support/network_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import 'package:yi_m1_reborn/application/camera_network.dart';
import 'package:yi_m1_reborn/application/pair_camera.dart';

const camera = DiscoveredCamera(id: 'candidate', name: 'YI M1');
const remembered = RememberedCamera(
  address: 'test-address',
  addressType: 'public',
  protocol: 1,
  referenceId: '42',
  token: 'test-token',
);

void main() {
  test(
    'Cleanup failure cannot replace the original unexpected error',
    () async {
      final events = <LogEvent>[];
      final store = MemoryStore()..camera = remembered;
      final network = BrokenCleanupNetwork();
      final error = StateError('original');
      final setup = PairCamera(
        pairing: SamplePairing(store),
        store: store,
        network: network,
        reachability: UnexpectedReachability(error),
        log: AppLog(sink: events.add),
      );
      await expectLater(setup.resumeRemembered(), throwsA(same(error)));
      expect(events.any((e) => e.event == 'connection.cleanup_failed'), isTrue);
    },
  );

  test(
    'Unexpected verification errors remain unexpected and release network',
    () async {
      final events = <LogEvent>[];
      final store = MemoryStore()..camera = remembered;
      final network = SampleNetwork();
      final error = StateError('private payload must not be logged');
      final setup = PairCamera(
        pairing: SamplePairing(store),
        store: store,
        network: network,
        reachability: UnexpectedReachability(error),
        log: AppLog(sink: events.add),
      );
      await expectLater(setup.resumeRemembered(), throwsA(same(error)));
      expect(network.session.closed, isTrue);
      final failure = events.singleWhere(
        (e) => e.event == 'connection.unexpected',
      );
      expect(failure.level, LogLevel.error);
      expect(failure.code, 'StateError');
      expect(failure.stackTrace, isNotNull);
    },
  );

  test(
    'Connection logs show stages and managed outcome without credentials',
    () async {
      final events = <LogEvent>[];
      final store = MemoryStore()..camera = remembered;
      final setup = PairCamera(
        pairing: SamplePairing(store),
        store: store,
        network: SampleNetwork(),
        reachability: FailingReachability(),
        log: AppLog(sink: events.add),
      );
      await expectLater(
        setup.resumeRemembered(),
        throwsA(isA<PairingFailure>()),
      );
      expect(events.first.event, 'connection.started');
      expect(
        events.where((e) => e.event == 'connection.stage').map((e) => e.stage),
        containsAllInOrder(['storage', 'session', 'wifi', 'verification']),
      );
      final failure = events.singleWhere((e) => e.event == 'connection.failed');
      expect(failure.level, LogLevel.error);
      expect(failure.stage, 'verification');
      expect(failure.elapsed, isNotNull);
      expect(failure.stackTrace, isNotNull);
      expect(
        events.map((e) => [e.event, e.stage, e.code].join(' ')).join(' '),
        isNot(contains('not-persisted')),
      );
    },
  );

  test(
    'C1: approved first pairing is saved before Wi-Fi and verified response',
    () async {
      final store = MemoryStore();
      final pairing = SamplePairing(store);
      final network = SampleNetwork();
      final response = SampleReachability();
      final setup = PairCamera(
        pairing: pairing,
        store: store,
        network: network,
        reachability: response,
      );
      await setup.pair(camera);
      expect(store.camera, same(remembered));
      expect(pairing.pairs, 1);
      expect(response.address, '192.168.0.20');
      expect(setup.connected, isTrue);
      await setup.cancel();
    },
  );

  test(
    'C3: known link loss while cleanup waits cannot report Connected',
    () async {
      final store = MemoryStore()..camera = remembered;
      final network = SampleNetwork();
      final setup = PairCamera(
        pairing: SamplePairing(store),
        store: store,
        network: network,
        reachability: LostReachability(network.session),
      );
      await expectLater(
        setup.resumeRemembered(),
        throwsA(isA<PairingFailure>()),
      );
      expect(network.session.closed, isTrue);
    },
  );

  test(
    'C3: a network ending during response verification cannot report Connected',
    () async {
      final store = MemoryStore()..camera = remembered;
      final network = SampleNetwork();
      final reachability = EndedReachability(network.session);
      final setup = PairCamera(
        pairing: SamplePairing(store),
        store: store,
        network: network,
        reachability: reachability,
      );
      await expectLater(
        setup.resumeRemembered(),
        throwsA(isA<PairingFailure>()),
      );
      expect(network.session.closed, isTrue);
    },
  );

  test('C3: Retry cannot overlap temporary network cleanup', () async {
    final store = MemoryStore()..camera = remembered;
    final network = ClosingNetwork();
    final setup = PairCamera(
      pairing: SamplePairing(store),
      store: store,
      network: network,
      reachability: SampleReachability(),
    );
    await setup.resumeRemembered();
    final closing = setup.cancel();
    await network.session.closing.future;
    await expectLater(setup.resumeRemembered(), throwsA(isA<PairingFailure>()));
    network.session.release.complete();
    await closing;
  });

  test(
    'C3: cancelled Wi-Fi join releases its late session before Retry becomes available',
    () async {
      final store = MemoryStore()..camera = remembered;
      final network = DelayedNetwork();
      final setup = PairCamera(
        pairing: SamplePairing(store),
        store: store,
        network: network,
        reachability: SampleReachability(),
      );
      final connection = setup.resumeRemembered();
      await network.started.future;
      await setup.cancel();
      await expectLater(
        setup.resumeRemembered(),
        throwsA(isA<PairingFailure>()),
      );
      final failure = expectLater(connection, throwsA(isA<PairingFailure>()));
      network.release.complete(network.session);
      await failure;
      expect(network.session.closed, isTrue);
    },
  );

  test(
    'C3: HTTP failure releases the temporary network and Retry never pairs',
    () async {
      final store = MemoryStore()..camera = remembered;
      final pairing = SamplePairing(store);
      final network = SampleNetwork();
      final setup = PairCamera(
        pairing: pairing,
        store: store,
        network: network,
        reachability: FailingReachability(),
      );

      await expectLater(
        setup.resumeRemembered(),
        throwsA(isA<PairingFailure>()),
      );

      expect(network.session.closed, isTrue);
      expect(pairing.pairs, 0);
      expect(store.camera, same(remembered));
    },
  );

  test(
    'C2: remembered connection joins with fresh credentials and verifies reachability before success',
    () async {
      final store = MemoryStore()..camera = remembered;
      final pairing = SamplePairing(store);
      final network = SampleNetwork();
      final reachability = SampleReachability();
      final setup = PairCamera(
        pairing: pairing,
        store: store,
        network: network,
        reachability: reachability,
      );

      expect(await setup.resumeRemembered(), isTrue);

      expect(network.credentials!.ssid, 'test-camera');
      expect(network.credentials!.password, 'not-persisted');
      expect(reachability.address, '192.168.0.20');
      expect(network.session.closed, isFalse);
      await setup.cancel();
    },
  );

  test(
    'C1: explicit pairing remembers approval before session setup',
    () async {
      final store = MemoryStore();
      final pairing = SamplePairing(store);
      final setup = PairCamera(pairing: pairing, store: store);

      await setup.pair(camera);

      expect(store.camera, same(remembered));
      expect(pairing.sessions, 1);
    },
  );
  test('C4: unavailable keyring stops before any pairing write', () async {
    final store = FailingReadStore();
    final pairing = SamplePairing(store);
    final setup = PairCamera(pairing: pairing, store: store);
    await expectLater(setup.pair(camera), throwsA(isA<PairingFailure>()));
    expect(pairing.pairs, 0);
    expect(pairing.sessions, 0);
  });
  test('C4: Retry saves an accepted token without pairing again', () async {
    final store = FailingSaveStore();
    final pairing = SamplePairing(store);
    final setup = PairCamera(pairing: pairing, store: store);
    await expectLater(setup.pair(camera), throwsA(isA<PairingFailure>()));
    expect(pairing.sessions, 0);
    expect(await setup.resumeRemembered(), isTrue);
    expect(pairing.pairs, 1);
    expect(pairing.sessions, 1);
  });
  test('C2: remembered session retries never start a new pairing', () async {
    final store = MemoryStore()..camera = remembered;
    final pairing = SessionFailurePairing(store);
    final setup = PairCamera(pairing: pairing, store: store);
    await expectLater(setup.resumeRemembered(), throwsA(isA<PairingFailure>()));
    expect(await setup.resumeRemembered(), isTrue);
    expect(pairing.pairs, 0);
    expect(pairing.sessions, 2);
  });
  test(
    'C3: disposed attempt cannot save or establish a late accepted session',
    () async {
      final store = MemoryStore();
      final pairing = DelayedPairing(store);
      final setup = PairCamera(pairing: pairing, store: store);
      final result = setup.pair(camera);
      await pairing.started.future;
      await setup.cancel();
      final assertion = expectLater(result, throwsA(isA<PairingFailure>()));
      pairing.approval.complete(remembered);
      await assertion;
      expect(store.camera, isNull);
      expect(pairing.sessions, 0);
    },
  );
  test('C1: overlapping Pair requests cannot send another pairing', () async {
    final store = MemoryStore();
    final pairing = DelayedPairing(store);
    final setup = PairCamera(pairing: pairing, store: store);
    final first = setup.pair(camera);
    await pairing.started.future;
    await expectLater(setup.pair(camera), throwsA(isA<PairingFailure>()));
    pairing.approval.complete(remembered);
    await first;
    expect(pairing.sessions, 1);
    expect(pairing.pairs, 1);
  });
  test(
    'C3: cancellation during resume cleanup cannot report success',
    () async {
      final store = MemoryStore()..camera = remembered;
      final pairing = CleanupPairing(store);
      final setup = PairCamera(pairing: pairing, store: store);
      final result = setup.resumeRemembered();
      await pairing.cleanup.future;
      await setup.cancel();
      final assertion = expectLater(result, throwsA(isA<PairingFailure>()));
      pairing.release.complete();
      await assertion;
    },
  );
}

class MemoryStore implements PairingStore {
  RememberedCamera? camera;
  @override
  Future<RememberedCamera?> read() async => camera;
  @override
  Future<void> save(RememberedCamera value) async {
    camera = value;
  }
}

class SamplePairing implements CameraPairing {
  SamplePairing(this.store);
  final MemoryStore store;
  int pairs = 0;
  int sessions = 0;
  @override
  Future<RememberedCamera> pair(
    DiscoveredCamera camera,
    PairingAttempt attempt,
  ) async {
    pairs++;
    return remembered;
  }

  @override
  Future<CameraWifiCredentials> resume(
    RememberedCamera value,
    PairingAttempt attempt,
  ) async {
    expect(
      store.camera,
      same(value),
      reason: 'Accepted pairing must be retained before proceeding',
    );
    sessions++;
    return const CameraWifiCredentials(
      ssid: 'test-camera',
      password: 'not-persisted',
    );
  }
}

class FailingReadStore extends MemoryStore {
  @override
  Future<RememberedCamera?> read() async => throw const PairingStorageFailure();
}

class FailingSaveStore extends MemoryStore {
  bool failNext = true;
  @override
  Future<void> save(RememberedCamera value) async {
    if (failNext) {
      failNext = false;
      throw const PairingStorageFailure();
    }
    await super.save(value);
  }
}

class SessionFailurePairing extends SamplePairing {
  SessionFailurePairing(super.store);
  @override
  Future<CameraWifiCredentials> resume(
    RememberedCamera value,
    PairingAttempt attempt,
  ) async {
    sessions++;
    if (sessions == 1) throw const PairingFailure('Camera session failed.');
    return const CameraWifiCredentials(
      ssid: 'test-camera',
      password: 'not-persisted',
    );
  }
}

class DelayedPairing extends SamplePairing {
  DelayedPairing(super.store);
  final approval = Completer<RememberedCamera>();
  final started = Completer<void>();
  @override
  Future<RememberedCamera> pair(
    DiscoveredCamera camera,
    PairingAttempt attempt,
  ) {
    pairs++;
    if (!started.isCompleted) started.complete();
    return approval.future;
  }
}

class CleanupPairing extends SamplePairing {
  CleanupPairing(super.store);
  final cleanup = Completer<void>();
  final release = Completer<void>();
  @override
  Future<CameraWifiCredentials> resume(
    RememberedCamera camera,
    PairingAttempt attempt,
  ) async {
    cleanup.complete();
    await release.future;
    return const CameraWifiCredentials(
      ssid: 'sample',
      password: 'not-persisted',
    );
  }
}

class FailingReachability implements CameraReachability {
  @override
  Future<void> verify(String address, PairingAttempt attempt) async {
    throw const PairingFailure('Camera reachability failed. Select Retry.');
  }
}

class DelayedNetwork extends SampleNetwork {
  final started = Completer<void>();
  final release = Completer<CameraNetworkSession>();
  @override
  Future<CameraNetworkSession> join(
    CameraWifiCredentials credentials,
    PairingAttempt attempt,
  ) {
    started.complete();
    return release.future;
  }
}

class ClosingNetwork implements CameraNetwork {
  final session = ClosingSession();
  @override
  Future<CameraNetworkSession> join(
    CameraWifiCredentials value,
    PairingAttempt attempt,
  ) async => session;
}

class ClosingSession extends SampleNetworkSession {
  final closing = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> close() async {
    closing.complete();
    await release.future;
    await super.close();
  }
}

class EndedReachability implements CameraReachability {
  EndedReachability(this.session);
  final SampleNetworkSession session;
  @override
  Future<void> verify(String address, PairingAttempt attempt) async {
    await session.close();
  }
}

class LostReachability implements CameraReachability {
  LostReachability(this.session);
  final SampleNetworkSession session;
  @override
  Future<void> verify(String address, PairingAttempt attempt) async {
    session.lostConnection.complete();
  }
}

class UnexpectedReachability implements CameraReachability {
  UnexpectedReachability(this.error);
  final Object error;
  @override
  Future<void> verify(String address, PairingAttempt attempt) async =>
      throw error;
}

class BrokenCleanupNetwork extends SampleNetwork {
  @override
  final session = BrokenCleanupSession();
}

class BrokenCleanupSession extends SampleNetworkSession {
  @override
  Future<void> close() async => throw StateError('cleanup');
}
