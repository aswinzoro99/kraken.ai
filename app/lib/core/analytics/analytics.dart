/// Product analytics, behind an interface so the app never depends on a
/// vendor SDK directly. Firebase Analytics plugs in as one more [Analytics]
/// sink when the Firebase projects exist.
///
/// Rules for every event:
/// * names and parameter keys are snake_case, start with a letter, ≤ 40 chars;
/// * values are strings (≤ 100 chars), numbers or booleans;
/// * no personal data: no emails, names, phone numbers, UPI IDs, amounts,
///   group names or message text. Send categories and counts instead.
library;

import 'package:flutter/foundation.dart';

abstract interface class Analytics {
  Future<void> log(AnalyticsEvent event);

  /// The Firebase uid, never an email. Null on sign-out.
  Future<void> setUserId(String? uid);
}

/// One analytics event. Concrete events live in `events.dart`.
abstract base class AnalyticsEvent {
  const AnalyticsEvent();

  String get name;

  Map<String, Object> get params => const {};

  @override
  String toString() => params.isEmpty ? name : '$name $params';
}

final _identifier = RegExp(r'^[a-z][a-z0-9_]{0,39}$');

/// Problems with [event] under the rules above; empty when it is valid.
List<String> validateEvent(AnalyticsEvent event) {
  final problems = <String>[];
  if (!_identifier.hasMatch(event.name)) problems.add('bad event name "${event.name}"');
  if (event.params.length > 25) problems.add('more than 25 params');
  event.params.forEach((key, value) {
    if (!_identifier.hasMatch(key)) problems.add('bad param key "$key"');
    if (value is String && value.length > 100) problems.add('"$key" longer than 100 chars');
    if (value is! String && value is! num && value is! bool) {
      problems.add('"$key" must be a string, number or bool');
    }
  });
  return problems;
}

/// Sends every event to several sinks (log, debug recorder, Firebase).
final class MultiAnalytics implements Analytics {
  const MultiAnalytics(this._sinks);
  final List<Analytics> _sinks;

  @override
  Future<void> log(AnalyticsEvent event) async {
    assert(() {
      final problems = validateEvent(event);
      if (problems.isNotEmpty) throw ArgumentError('Invalid analytics event: ${problems.join('; ')}');
      return true;
    }());
    await Future.wait(_sinks.map((s) => s.log(event)));
  }

  @override
  Future<void> setUserId(String? uid) async {
    await Future.wait(_sinks.map((s) => s.setUserId(uid)));
  }
}

/// A recorded event, for the debug screen and tests.
@immutable
final class RecordedEvent {
  const RecordedEvent(this.name, this.params, this.at);
  final String name;
  final Map<String, Object> params;
  final DateTime at;
}

/// Keeps the last [capacity] events in memory. Nothing leaves the phone.
final class RecordingAnalytics extends ChangeNotifier implements Analytics {
  RecordingAnalytics({this.capacity = 200});

  final int capacity;
  final List<RecordedEvent> _events = [];
  String? _userId;

  List<RecordedEvent> get events => List.unmodifiable(_events);
  Iterable<String> get names => _events.map((e) => e.name);
  String? get userId => _userId;

  @override
  Future<void> log(AnalyticsEvent event) async {
    _events.add(RecordedEvent(event.name, Map.unmodifiable(event.params), DateTime.now()));
    if (_events.length > capacity) _events.removeAt(0);
    notifyListeners();
  }

  @override
  Future<void> setUserId(String? uid) async {
    _userId = uid;
    notifyListeners();
  }

  void clear() {
    _events.clear();
    notifyListeners();
  }
}
