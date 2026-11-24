import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'consent_gated_analytics.dart';
import 'events.dart';

/// The usage-stats choice, for the Account switch. Follows choices made
/// anywhere, including the sign-up chat.
class AnalyticsConsentCubit extends Cubit<AnalyticsConsent> {
  AnalyticsConsentCubit(this._analytics) : super(_analytics.consent) {
    _sub = _analytics.changes.listen(emit);
  }

  final ConsentGatedAnalytics _analytics;
  late final StreamSubscription<AnalyticsConsent> _sub;

  Future<void> set({required bool granted}) async {
    // Log while still allowed, so turning stats off is the last event sent.
    if (!granted) await _analytics.log(const SettingChanged(setting: 'usage_stats', enabled: false));
    await _analytics.setConsent(granted ? AnalyticsConsent.granted : AnalyticsConsent.denied);
    if (granted) await _analytics.log(const SettingChanged(setting: 'usage_stats', enabled: true));
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
