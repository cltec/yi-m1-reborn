import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/adapters/console_log.dart';
import 'package:yi_m1_reborn/application/diagnostics.dart';

void main() {
  test(
    'Console output keeps safe diagnostic fields and code stack locations',
    () {
      final record = logRecord(
        LogEvent(
          LogLevel.error,
          'wifi.failed',
          stage: 'activation',
          code: 'AccessDenied',
          state: 4,
          reason: 7,
          elapsed: const Duration(milliseconds: 5),
          stackTrace: StackTrace.fromString(
            'secret-platform-message\n#0 method (package:yi_m1_reborn/main.dart:1:2) raw-platform-secret\n#1 raw (/home/private/path.dart:3:4)',
          ),
        ),
      );
      expect(record['level'], 'error');
      expect(record['stage'], 'activation');
      expect(record['reason'], 7);
      expect(record['elapsedMs'], 5);
      expect(record['stack'], ['package:yi_m1_reborn/main.dart:1:2']);
      expect(record.toString(), isNot(contains('secret-platform-message')));
      expect(record.toString(), isNot(contains('/home/private')));
    },
  );
}
