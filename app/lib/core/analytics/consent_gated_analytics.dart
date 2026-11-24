import 'dart:async';

import 'analytics.dart';

enum AnalyticsConsent { unknown, granted, denied }

/// Holds analytics back until the person decides, as the privacy notice
/// promises (DPDP: consent before processing).
///
/// * unknown: events are buffered in memory (the sign-up funnel happens
///   before the consent question);
/// * granted: the buffer is flushed and events flow to the delegate;
/// * denied: the buffer is discarded and later events are dropped.
final class ConsentGatedAnalytics implements Analytics {
  ConsentGatedAnalytics(
    this._delegate, {
    AnalyticsConsent initial = AnalyticsConsent.unknown,
    this.maxBuffered = 100,
    this.onConsentChanged,
  }) : _consent = initial;

  final Analytics _delegate;
  final int maxBuffered;
  final void Function(AnalyticsConsent consent)? onConsentChanged;

  AnalyticsConsent _consent;
  final List<AnalyticsEvent> _buffer = [];
  String? _pendingUserId;
  bool _hasPendingUserId = false;

  final _changes = StreamController<AnalyticsConsent>.broadcast();

  AnalyticsConsent get consent => _consent;

  /// Emits each new choice, wherever it was made.
  Stream<AnalyticsConsent> get changes => _changes.stream;
  int get bufferedCount => _buffer.length;

  Future<void> setConsent(AnalyticsConsent consent) async {
    if (consent == _consent) return;
    _consent = consent;
    onConsentChanged?.call(consent);
    _changes.add(consent);
    switch (consent) {
      case AnalyticsConsent.granted:
        if (_hasPendingUserId) await _delegate.setUserId(_pendingUserId);
        final pending = List.of(_buffer);
        _buffer.clear();
        for (final event in pending) {
          await _delegate.log(event);
        }
      case AnalyticsConsent.denied:
        _buffer.clear();
        _hasPendingUserId = false;
        await _delegate.setUserId(null);
      case AnalyticsConsent.unknown:
        break;
    }
  }

  @override
  Future<void> log(AnalyticsEvent event) async {
    switch (_consent) {
      case AnalyticsConsent.granted:
        await _delegate.log(event);
      case AnalyticsConsent.unknown:
        _buffer.add(event);
        if (_buffer.length > maxBuffered) _buffer.removeAt(0);
      case AnalyticsConsent.denied:
        break;
    }
  }

  @override
  Future<void> setUserId(String? uid) async {
    switch (_consent) {
      case AnalyticsConsent.granted:
        await _delegate.setUserId(uid);
      case AnalyticsConsent.unknown:
        _pendingUserId = uid;
        _hasPendingUserId = true;
      case AnalyticsConsent.denied:
        break;
    }
  }
}
