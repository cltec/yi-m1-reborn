enum LogLevel { debug, info, warning, error }

/// Diagnostic fields contain only application event names and safe codes.
/// Never pass platform messages, credentials, addresses or payloads here.
class LogEvent {
  const LogEvent(
    this.level,
    this.event, {
    this.stage,
    this.elapsed,
    this.code,
    this.state,
    this.reason,
    this.stackTrace,
  });
  final LogLevel level;
  final String event;
  final String? stage;
  final Duration? elapsed;
  final String? code;
  final int? state;
  final int? reason;
  final StackTrace? stackTrace;
}

/// Composition supplies a nonthrowing sink; the default keeps test fixtures quiet.
class AppLog {
  const AppLog({this.sink, this.minimumLevel = LogLevel.info});
  final void Function(LogEvent)? sink;
  final LogLevel minimumLevel;

  void emit(
    LogLevel level,
    String event, {
    String? stage,
    Duration? elapsed,
    String? code,
    int? state,
    int? reason,
    StackTrace? stackTrace,
  }) {
    if (level.index < minimumLevel.index) return;
    sink?.call(
      LogEvent(
        level,
        event,
        stage: stage,
        elapsed: elapsed,
        code: code,
        state: state,
        reason: reason,
        stackTrace: stackTrace,
      ),
    );
  }
}
