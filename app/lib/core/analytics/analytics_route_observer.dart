import 'package:material_ui/material_ui.dart';

import 'analytics.dart';
import 'events.dart';

/// Logs a `screen_view` whenever a named page becomes visible.
/// Route names come from `GoRoute(name: ...)`, never from paths, so no ids
/// or personal data leak into analytics.
class AnalyticsRouteObserver extends NavigatorObserver {
  AnalyticsRouteObserver(this._analytics);

  final Analytics _analytics;

  void _report(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    _analytics.log(ScreenViewed(name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _report(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _report(newRoute);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _report(previousRoute);
}
