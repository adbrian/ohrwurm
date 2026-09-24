import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'clip_player.dart';

/// [ClipPlayer] on `just_audio`, with two players: while one plays, the other loads the clip the
/// engine says is next, so [play] starts without the 60–550 ms load (A0; APP_SPEC 11.1).
///
/// Interruptions (calls) are handled by the Listen screen, which stops and restarts the engine,
/// so the players don't handle them themselves.
class JustAudioClipPlayer implements ClipPlayer {
  final List<AudioPlayer> _players = [
    AudioPlayer(handleInterruptions: false),
    AudioPlayer(handleInterruptions: false),
  ];

  /// The URI loaded, or loading, in each player.
  final List<String?> _loaded = [null, null];
  final List<Future<void>?> _loading = [null, null];

  int _active = 0;

  /// Bumped by every [play] and [stop]: a load or a completion from an older call is ignored.
  int _token = 0;
  Completer<void>? _done;

  double _speed = 1;

  /// Clip speed, 0.75–1.25 (APP_SPEC 14). Pauses aren't affected.
  set speed(double value) => _speed = value;

  @override
  Future<void> play(String uri) async {
    _finish();
    final token = ++_token;
    final done = Completer<void>();
    _done = done;
    // Chosen before any await, so a [preload] right after this call loads the other player.
    var i = _loaded.indexOf(uri);
    if (i < 0) {
      i = 1 - _active;
      _load(i, uri);
    }
    _active = i;
    try {
      await _loading[i];
      if (token != _token) return;
      final player = _players[i];
      await player.seek(Duration.zero);
      if (token != _token) return;
      await player.setSpeed(_speed);
      if (token != _token) return;
      // `play()` completes when the clip ends, or when it's paused by [stop] (A0).
      unawaited(
        player.play().then(
          (_) {
            if (token == _token) _finish();
          },
          onError: (Object e) {
            if (token == _token) _finish(error: e);
          },
        ),
      );
    } catch (e) {
      // Loading failed, e.g. the file is gone. Forget it so a later play tries again.
      _forget(uri);
      if (token != _token) return;
      _done = null;
      rethrow;
    }
    return done.future;
  }

  @override
  Future<void> stop() async {
    _token++;
    _finish();
    await _players[_active].pause();
  }

  @override
  void preload(String uri) {
    if (_loaded.contains(uri)) return;
    // Never into the player that's playing.
    _load(1 - _active, uri);
  }

  void _load(int i, String uri) {
    _loaded[i] = uri;
    final loading = _players[i].setAudioSource(AudioSource.uri(Uri.parse(uri))).then((_) {});
    _loading[i] = loading;
    // A failed preload surfaces when [play] awaits it; don't let it go unhandled meanwhile.
    unawaited(loading.catchError((_) => _forget(uri)));
  }

  void _forget(String uri) {
    final i = _loaded.indexOf(uri);
    if (i >= 0) {
      _loaded[i] = null;
      _loading[i] = null;
    }
  }

  /// Completes the current [play]: normally, or with [error] when the clip failed mid-way.
  void _finish({Object? error}) {
    final done = _done;
    _done = null;
    if (done == null || done.isCompleted) return;
    if (error == null) {
      done.complete();
    } else {
      done.completeError(error);
    }
  }

  Future<void> dispose() async {
    _token++;
    _finish();
    for (final p in _players) {
      await p.dispose();
    }
  }
}
