/// Source of the current time, replaceable in tests.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();

/// Timestamps written by the app are stored as UTC ISO 8601 text.
String timestamp(Clock clock) => clock().toUtc().toIso8601String();
