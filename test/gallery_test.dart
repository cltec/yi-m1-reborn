import 'dart:async';
import '../test_support/network_fixture.dart';
import '../test_support/pairing_fixture.dart';
import 'package:yi_m1_reborn/application/camera_network.dart';
import 'package:flutter/material.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import 'package:yi_m1_reborn/application/pair_camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/presentation/gallery.dart';
import 'package:yi_m1_reborn/application/discovery_approval.dart';

void main() {
  testWidgets('Unexpected Pair fault stops progress without normal Retry', (
    tester,
  ) async {
    await tester.pumpWidget(
      GalleryApp(
        discovery: SampleDiscovery(),
        pairing: PairCamera(
          pairing: UnexpectedPairing(),
          store: PreviewStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('YI M1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNotNull);
    expect(
      find.text('Unexpected application error. See diagnostic logs.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets(
    'Unexpected verification fault stops progress and has no normal Retry',
    (tester) async {
      await tester.pumpWidget(
        GalleryApp(
          discovery: SampleDiscovery(),
          pairing: PairCamera(
            pairing: PreviewPairing(),
            store: PreviewStore()..camera = previewRemembered,
            network: SampleNetwork(),
            reachability: UnexpectedUiReachability(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isA<StateError>());
      expect(find.text('Checking camera response'), findsNothing);
      expect(
        find.text('Unexpected application error. See diagnostic logs.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'Unexpected connection error is reported, not offered as normal Retry',
    (tester) async {
      await tester.pumpWidget(GalleryApp(discovery: UnexpectedDiscovery()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isA<StateError>());
      expect(
        find.text('Unexpected application error. See diagnostic logs.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'C3: known link loss hides Connected before cleanup and withholds Retry',
    (tester) async {
      final network = SampleNetwork();
      final response = WaitingReachability()..response.complete();
      await tester.pumpWidget(
        GalleryApp(
          discovery: SampleDiscovery(),
          pairing: PairCamera(
            pairing: PreviewPairing(),
            store: PreviewStore()..camera = previewRemembered,
            network: network,
            reachability: response,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      network.session.lostConnection.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Connected'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Releasing camera network'), findsOneWidget);
      network.session.disconnected.complete();
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets(
    'C2: Connected is shown only after camera response, and link end requires manual Retry',
    (tester) async {
      final store = PreviewStore()..camera = previewRemembered;
      final network = SampleNetwork();
      final reachability = WaitingReachability();
      await tester.pumpWidget(
        GalleryApp(
          discovery: SampleDiscovery(),
          pairing: PairCamera(
            pairing: PreviewPairing(),
            store: store,
            network: network,
            reachability: reachability,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Checking camera response'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
      reachability.response.complete();
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('No photos'), findsNothing);
      await network.session.close();
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsNothing);
      expect(
        find.textContaining('Camera network connection ended'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );

  testWidgets('C1: launch discovers a camera without claiming a connection', (
    tester,
  ) async {
    await tester.pumpWidget(GalleryApp(discovery: SampleDiscovery()));
    await tester.pumpAndSettle();

    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Select a camera'), findsOneWidget);
    expect(find.text('YI M1'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    expect(find.text('No photos'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Pair'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('C1: camera selection is explicit and does not connect', (
    tester,
  ) async {
    await tester.pumpWidget(GalleryApp(discovery: SampleDiscovery()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('YI M1'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('YI M1'), findsOneWidget);
    expect(find.text('Selected: YI M1'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('C3: discovery failure stops with manual Retry', (tester) async {
    final discovery = RetryDiscovery();
    await tester.pumpWidget(GalleryApp(discovery: discovery));
    await tester.pumpAndSettle();

    expect(find.text('Camera discovery failed'), findsOneWidget);
    expect(find.text('Bluetooth is unavailable.'), findsOneWidget);
    expect(discovery.attempts, 1);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('YI M1'), findsOneWidget);
    expect(discovery.attempts, 2);
    expect(find.text('Connected'), findsNothing);
  });

  testWidgets('C3: no discovered cameras is not an empty gallery', (
    tester,
  ) async {
    await tester.pumpWidget(GalleryApp(discovery: EmptyDiscovery()));
    await tester.pumpAndSettle();
    expect(find.text('No camera found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('No photos'), findsNothing);
  });
  testWidgets('C3: a default launch never starts an unauthorized scan', (
    tester,
  ) async {
    await tester.pumpWidget(GalleryApp(discovery: DiscoveryApprovalRequired()));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Bluetooth discovery has not been authorized'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
  });
  testWidgets('C1: Pair needs selection and waits for camera approval', (
    tester,
  ) async {
    final pairing = PendingPairing();
    final setup = PairCamera(pairing: pairing, store: EmptyStore());
    await tester.pumpWidget(
      GalleryApp(discovery: SampleDiscovery(), pairing: setup),
    );
    await tester.pumpAndSettle();
    expect(pairing.pairs, 0);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Pair'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('YI M1'));
    await tester.pumpAndSettle();
    expect(pairing.pairs, 0);
    await tester.tap(find.text('Pair'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Approve pairing on the camera'), findsOneWidget);
    expect(pairing.pairs, 1);
    pairing.approval.completeError(
      const PairingFailure('Camera refused pairing.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Camera refused pairing.'), findsOneWidget);
    expect(find.text('Connected'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(pairing.pairs, 1);
    expect(find.text('Select a camera'), findsOneWidget);
  });

  testWidgets('C4: keyring read failure stops before discovery or pairing', (
    tester,
  ) async {
    final discovery = CountingDiscovery();
    final pairing = PendingPairing();
    await tester.pumpWidget(
      GalleryApp(
        discovery: discovery,
        pairing: PairCamera(pairing: pairing, store: UnavailableStore()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.textContaining('Pairing storage is unavailable'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(discovery.calls, 0);
    expect(pairing.pairs, 0);
  });
}

class SampleDiscovery implements CameraDiscovery {
  @override
  Future<List<DiscoveredCamera>> discover() async => [
    const DiscoveredCamera(id: 'test-camera', name: 'YI M1'),
  ];
}

class RetryDiscovery extends SampleDiscovery {
  int attempts = 0;

  @override
  Future<List<DiscoveredCamera>> discover() async {
    attempts++;
    if (attempts == 1)
      throw const DiscoveryFailure('Bluetooth is unavailable.');
    return super.discover();
  }
}

class EmptyDiscovery implements CameraDiscovery {
  @override
  Future<List<DiscoveredCamera>> discover() async => [];
}

class EmptyStore implements PairingStore {
  @override
  Future<RememberedCamera?> read() async => null;
  @override
  Future<void> save(RememberedCamera camera) async {}
}

class PendingPairing implements CameraPairing {
  int pairs = 0;
  final approval = Completer<RememberedCamera>();
  @override
  Future<RememberedCamera> pair(
    DiscoveredCamera camera,
    PairingAttempt attempt,
  ) {
    pairs++;
    return approval.future;
  }

  @override
  Future<CameraWifiCredentials> resume(
    RememberedCamera camera,
    PairingAttempt attempt,
  ) async => const CameraWifiCredentials(ssid: 'sample', password: 'sample');
}

class CountingDiscovery extends SampleDiscovery {
  int calls = 0;
  @override
  Future<List<DiscoveredCamera>> discover() {
    calls++;
    return super.discover();
  }
}

class UnavailableStore extends EmptyStore {
  @override
  Future<RememberedCamera?> read() async => throw const PairingStorageFailure();
}

class WaitingReachability implements CameraReachability {
  final response = Completer<void>();
  @override
  Future<void> verify(String address, PairingAttempt attempt) =>
      attempt.wait(response.future);
}

class UnexpectedDiscovery implements CameraDiscovery {
  @override
  Future<List<DiscoveredCamera>> discover() async =>
      throw StateError('unexpected');
}

class UnexpectedUiReachability implements CameraReachability {
  @override
  Future<void> verify(String address, PairingAttempt attempt) async =>
      throw StateError('unexpected');
}

class UnexpectedPairing extends PreviewPairing {
  @override
  Future<RememberedCamera> pair(
    DiscoveredCamera camera,
    PairingAttempt attempt,
  ) async => throw StateError('unexpected pair');
}
