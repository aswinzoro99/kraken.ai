import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// A small tagged logger. Logs go to the Dart developer log (visible in
/// DevTools and `flutter run`), never to analytics.
///
/// Never log personal data: no emails, names, amounts or codes.
class Logger {
  const Logger(this.tag, {this.minLevel = kReleaseMode ? LogLevel.warning : LogLevel.debug});

  final String tag;
  final LogLevel minLevel;

  Logger child(String sub) => Logger('$tag.$sub', minLevel: minLevel);

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message, [Object? error, StackTrace? stack]) => _log(LogLevel.warning, message, error, stack);
  void error(String message, [Object? error, StackTrace? stack]) => _log(LogLevel.error, message, error, stack);

  void _log(LogLevel level, String message, [Object? error, StackTrace? stack]) {
    if (level.index < minLevel.index) return;
    developer.log(
      message,
      name: tag,
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: stack,
    );
  }
}
