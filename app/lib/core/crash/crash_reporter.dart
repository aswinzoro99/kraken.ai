import '../logging/logger.dart';

/// Records crashes and unexpected errors.
///
/// The Firebase Crashlytics adapter arrives with the Firebase projects
/// (Phase 0, day 5). Until then [LoggingCrashReporter] writes to the log.
abstract interface class CrashReporter {
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false, String? reason});

  /// A breadcrumb shown next to the next crash. No personal data.
  void breadcrumb(String message);

  Future<void> setUserId(String? uid);
}

final class LoggingCrashReporter implements CrashReporter {
  LoggingCrashReporter([this._log = const Logger('crash')]);

  final Logger _log;
  final List<String> _breadcrumbs = [];

  List<String> get breadcrumbs => List.unmodifiable(_breadcrumbs);

  @override
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false, String? reason}) async {
    _log.error('${fatal ? 'FATAL' : 'non-fatal'}${reason == null ? '' : ' ($reason)'}', error, stack);
  }

  @override
  void breadcrumb(String message) {
    _breadcrumbs.add(message);
    if (_breadcrumbs.length > 50) _breadcrumbs.removeAt(0);
  }

  @override
  Future<void> setUserId(String? uid) async {}
}
