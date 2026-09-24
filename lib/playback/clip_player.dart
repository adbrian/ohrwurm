/// Plays one clip at a time (APP_SPEC 11.1). The engine depends on this interface only, never on
/// `just_audio`, so it can be tested with a fake player.
abstract class ClipPlayer {
  /// Plays the clip at [uri] (a `content://` URI, A0). Completes when the clip finishes **or**
  /// when [stop] is called.
  Future<void> play(String uri);

  /// Stops the clip that's playing, if any; its [play] completes.
  Future<void> stop();

  /// A hint that [uri] is probably the next clip [play] will get, so the player can load it
  /// ahead of time (loading takes 60–550 ms, A0). Returns at once: the engine never awaits it,
  /// so it adds no `await` to the engine (APP_SPEC 11.1, 11.3). A wrong hint costs nothing but
  /// the load it saved.
  void preload(String uri);
}
