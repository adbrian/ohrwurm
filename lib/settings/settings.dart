import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../playback/listen_engine.dart';

/// Clip speeds (APP_SPEC 14). Speed applies to clips, not pauses (APP_SPEC 11.5).
const speeds = [0.75, 1.0, 1.25];

/// The five pauses (APP_SPEC 11.4), in the order Settings lists them.
enum PauseKind {
  afterWord,
  afterTranslation,
  afterGermanSentence,
  afterEnglishSentence,
  betweenCards,
}

/// Where settings are kept between launches: `shared_preferences` (APP_SPEC 6).
abstract class SettingsStore {
  Future<Map<String, Object>> load();
  Future<void> save(String key, Object value);
}

class PrefsSettingsStore implements SettingsStore {
  final _prefs = SharedPreferencesAsync();

  @override
  Future<Map<String, Object>> load() async {
    final out = <String, Object>{};
    for (final kind in PauseKind.values) {
      final ms = await _prefs.getInt('pause_${kind.name}');
      if (ms != null) out['pause_${kind.name}'] = ms;
    }
    final speed = await _prefs.getDouble('speed');
    if (speed != null) out['speed'] = speed;
    final keepOn = await _prefs.getBool('keep_screen_on');
    if (keepOn != null) out['keep_screen_on'] = keepOn;
    return out;
  }

  @override
  Future<void> save(String key, Object value) => switch (value) {
    int v => _prefs.setInt(key, v),
    double v => _prefs.setDouble(key, v),
    bool v => _prefs.setBool(key, v),
    _ => throw ArgumentError('Unsupported setting type for $key'),
  };
}

/// Pause lengths, speed and keep-screen-on (APP_SPEC 14).
class AppSettings extends ChangeNotifier {
  final SettingsStore store;

  AppSettings(this.store);

  static const defaults = Pauses();

  /// Slider bounds for every pause, in milliseconds.
  static const minPauseMs = 0;
  static const maxPauseMs = 5000;
  static const pauseStepMs = 100;

  final Map<PauseKind, int> _pauseMs = {for (final kind in PauseKind.values) kind: defaultMs(kind)};
  double _speed = 1;
  bool _keepScreenOn = true;

  static int defaultMs(PauseKind kind) => switch (kind) {
    PauseKind.afterWord => defaults.afterWord,
    PauseKind.afterTranslation => defaults.afterTranslation,
    PauseKind.afterGermanSentence => defaults.afterGermanSentence,
    PauseKind.afterEnglishSentence => defaults.afterEnglishSentence,
    PauseKind.betweenCards => defaults.betweenCards,
  }.inMilliseconds;

  Future<void> load() async {
    final saved = await store.load();
    for (final kind in PauseKind.values) {
      final ms = saved['pause_${kind.name}'];
      if (ms is int) _pauseMs[kind] = ms.clamp(minPauseMs, maxPauseMs);
    }
    final speed = saved['speed'];
    if (speed is double && speeds.contains(speed)) _speed = speed;
    final keepOn = saved['keep_screen_on'];
    if (keepOn is bool) _keepScreenOn = keepOn;
    notifyListeners();
  }

  int pauseMs(PauseKind kind) => _pauseMs[kind]!;

  Pauses get pauses => Pauses(
    afterWord: Duration(milliseconds: _pauseMs[PauseKind.afterWord]!),
    afterTranslation: Duration(milliseconds: _pauseMs[PauseKind.afterTranslation]!),
    afterGermanSentence: Duration(milliseconds: _pauseMs[PauseKind.afterGermanSentence]!),
    afterEnglishSentence: Duration(milliseconds: _pauseMs[PauseKind.afterEnglishSentence]!),
    betweenCards: Duration(milliseconds: _pauseMs[PauseKind.betweenCards]!),
  );

  double get speed => _speed;

  /// Default on (APP_SPEC 14).
  bool get keepScreenOn => _keepScreenOn;

  void setPause(PauseKind kind, int ms) {
    final value = ms.clamp(minPauseMs, maxPauseMs);
    if (_pauseMs[kind] == value) return;
    _pauseMs[kind] = value;
    notifyListeners();
    store.save('pause_${kind.name}', value);
  }

  void setSpeed(double value) {
    if (!speeds.contains(value) || value == _speed) return;
    _speed = value;
    notifyListeners();
    store.save('speed', value);
  }

  void setKeepScreenOn(bool value) {
    if (value == _keepScreenOn) return;
    _keepScreenOn = value;
    notifyListeners();
    store.save('keep_screen_on', value);
  }
}
