import '../logging/logger.dart';
import 'analytics.dart';

/// Writes events to the developer log. Used in mock and dev builds.
final class LoggingAnalytics implements Analytics {
  const LoggingAnalytics([this._log = const Logger('analytics')]);
  final Logger _log;

  @override
  Future<void> log(AnalyticsEvent event) async => _log.debug('event $event');

  @override
  Future<void> setUserId(String? uid) async => _log.debug('user id ${uid == null ? 'cleared' : 'set'}');
}
