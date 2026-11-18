import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/application/camera_pairing.dart';

void main() {
  test('C3: cancellation promptly ends a silent camera wait', () async {
    final attempt = PairingAttempt(limit: const Duration(seconds: 1));
    final watch = Stopwatch()..start();
    final waiting = attempt.wait(Completer<void>().future);
    final check = expectLater(waiting, throwsA(isA<PairingFailure>()));
    attempt.cancel();
    await check;
    expect(watch.elapsed, lessThan(const Duration(milliseconds: 200)));
  });
}
