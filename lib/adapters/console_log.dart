import 'dart:convert';
import 'dart:io';
import '../application/diagnostics.dart';

/// Writes diagnostics to stderr; does not create a persistent log file.
void consoleLog(LogEvent event) {
  stderr.writeln(jsonEncode(logRecord(event)));
}

Map<String, Object> logRecord(LogEvent event) => {
  'time': DateTime.now().toUtc().toIso8601String(),
  'level': event.level.name,
  'event': event.event,
  if (event.stage != null) 'stage': event.stage!,
  if (event.elapsed != null) 'elapsedMs': event.elapsed!.inMilliseconds,
  if (event.code != null) 'code': event.code!,
  if (event.state != null) 'state': event.state!,
  if (event.reason != null) 'reason': event.reason!,
  // Extract code locations rather than forwarding arbitrary trace text.
  if (event.stackTrace != null)
    'stack': [
      for (final line in event.stackTrace.toString().split('\n'))
        if (RegExp(
              r'\((package:yi_m1_reborn/[A-Za-z0-9_./-]+\.dart:\d+:\d+|dart:[A-Za-z0-9_./-]+:\d+:\d+)\)',
            ).firstMatch(line)
            case final match?)
          match.group(1)!,
    ],
};
