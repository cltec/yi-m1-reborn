import 'package:flutter_test/flutter_test.dart';
import 'package:yi_m1_reborn/application/diagnostics.dart';

void main() {
  test('Essential outcomes remain while development logs require debug', () {
    final events = <LogEvent>[];
    final log = AppLog(sink: events.add);
    log.emit(LogLevel.debug, 'detail');
    log.emit(LogLevel.info, 'started');
    log.emit(LogLevel.warning, 'degraded');
    log.emit(LogLevel.error, 'failed');
    expect(events.map((e) => e.level), [
      LogLevel.info,
      LogLevel.warning,
      LogLevel.error,
    ]);
    AppLog(
      sink: events.add,
      minimumLevel: LogLevel.debug,
    ).emit(LogLevel.debug, 'detail');
    expect(events.last.level, LogLevel.debug);
  });
}
