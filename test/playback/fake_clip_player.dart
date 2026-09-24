import 'dart:async';

import 'package:ohrwurm/playback/clip_player.dart';

/// A [ClipPlayer] backed by timers (APP_SPEC 11.1): each clip "plays" for [clipLength], then its
/// [play] completes. Run it under `fakeAsync` to move time by hand.
class FakeClipPlayer implements ClipPlayer {
  Duration clipLength;

  /// URIs whose [play] throws, as a clip that can't be loaded does.
  final Set<String> failing = {};

  FakeClipPlayer({this.clipLength = const Duration(milliseconds: 1000)});

  /// Every [play] call, in order.
  final played = <String>[];

  /// Every [preload] hint, in order.
  final preloaded = <String>[];

  int stops = 0;

  /// The clip playing now, or null.
  String? get playing => _current == null ? null : _uri;

  String? _uri;
  Completer<void>? _current;
  Timer? _timer;

  @override
  Future<void> play(String uri) {
    played.add(uri);
    if (failing.contains(uri)) return Future.error(StateError('Clip not found: $uri'));
    _finish();
    final done = Completer<void>();
    _uri = uri;
    _current = done;
    _timer = Timer(clipLength, () {
      if (identical(_current, done)) _finish();
    });
    return done.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    _finish();
  }

  @override
  void preload(String uri) => preloaded.add(uri);

  void _finish() {
    _timer?.cancel();
    _timer = null;
    final current = _current;
    _current = null;
    _uri = null;
    if (current != null && !current.isCompleted) current.complete();
  }
}
