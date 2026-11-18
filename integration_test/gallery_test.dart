import 'package:flutter/material.dart';
import 'package:yi_m1_reborn/application/camera_network.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import '../test_support/network_fixture.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test_support/pairing_fixture.dart';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/application/pair_camera.dart';
import 'package:yi_m1_reborn/presentation/gallery.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'C2/C3/C6: simulated remembered connection waits for camera response and retries failure by keyboard',
    (tester) async {
      final store = PreviewStore()..camera = previewRemembered;
      final network = RetryNetwork();
      final reachability = PreviewReachability();
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
      await tester.pumpAndSettle();
      expect(
        find.text('Camera response check failed. Select Retry.'),
        findsOneWidget,
      );
      expect(find.text('Connected'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Connected'), findsOneWidget);
      expect(
        find.text('Camera is reachable. Photo filenames are not loaded yet.'),
        findsOneWidget,
      );
      expect(find.text('No photos'), findsNothing);
      expect(reachability.calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'C6: select a simulated camera by keyboard at both window sizes',
    (tester) async {
      for (final size in [const Size(1000, 700), const Size(640, 480)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          GalleryApp(key: UniqueKey(), discovery: SampleDiscovery()),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.text('Selected: YI M1'), findsOneWidget);
        expect(find.text('Connected'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
  testWidgets('C6: keyboard Retry recovers from a simulated discovery error', (
    tester,
  ) async {
    final discovery = RetryDiscovery();
    await tester.pumpWidget(GalleryApp(discovery: discovery));
    await tester.pumpAndSettle();
    expect(find.text('Camera discovery failed'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('YI M1'), findsOneWidget);
    expect(discovery.attempts, 2);
  });
  testWidgets(
    'C1/C6: keyboard Pair waits for camera and reports session without Wi-Fi',
    (tester) async {
      final pairing = PreviewPairing();
      await tester.pumpWidget(
        GalleryApp(
          discovery: SampleDiscovery(),
          pairing: PairCamera(pairing: pairing, store: PreviewStore()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(pairing.pairs, 0);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump();
      expect(find.text('Approve pairing on the camera'), findsOneWidget);
      pairing.approval.complete(previewRemembered);
      await tester.pumpAndSettle();
      expect(find.textContaining('BLE session verified'), findsOneWidget);
      expect(find.text('Connected'), findsNothing);
      expect(pairing.pairs, 1);
    },
  );
}

class SampleDiscovery implements CameraDiscovery {
  @override
  Future<List<DiscoveredCamera>> discover() async => [
    const DiscoveredCamera(id: 'sample', name: 'YI M1'),
  ];
}

class RetryDiscovery extends SampleDiscovery {
  int attempts = 0;

  @override
  Future<List<DiscoveredCamera>> discover() async {
    if (++attempts == 1)
      throw const DiscoveryFailure('Simulated unavailable Bluetooth.');
    return super.discover();
  }
}

class RetryNetwork implements CameraNetwork {
  @override
  Future<CameraNetworkSession> join(
    CameraWifiCredentials credentials,
    PairingAttempt attempt,
  ) async => SampleNetworkSession();
}

class PreviewReachability implements CameraReachability {
  int calls = 0;
  @override
  Future<void> verify(String address, PairingAttempt attempt) async {
    if (++calls == 1)
      throw const PairingFailure('Camera response check failed. Select Retry.');
  }
}
