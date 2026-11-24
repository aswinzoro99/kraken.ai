/// Returns the current time. Injected so tests can control time.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();
