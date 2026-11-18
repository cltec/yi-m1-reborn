import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/application/camera_connection.dart';
import 'package:yi_m1_reborn/application/pair_camera.dart';
import '../../test_support/pairing_fixture.dart';

void main() {
  test(
    'Existing pairing workflow fulfills the Gallery connection contract',
    () async {
      final CameraConnection connection = PairCamera(
        pairing: PreviewPairing(),
        store: PreviewStore(),
      );
      expect(await connection.resumeRemembered(), isFalse);
      expect(connection.connected, isFalse);
      expect(connection.verifiedSession, isNull);
      await connection.cancel();
    },
  );
}
