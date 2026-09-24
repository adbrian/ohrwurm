import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// What another app or a call asks of our audio (APP_SPEC 11.5).
enum Interruption {
  /// A call or another app takes the audio: stop.
  pauseBegin,

  /// It's over, and we may play again.
  pauseEnd,
}

/// The platform side of a session screen: the audio session, interruptions, and keeping the
/// screen on. An interface so session screens can be tested without plugins.
abstract class AudioHost {
  /// Sets the audio session up for playing (Listen) or for playing and recording (Mirror,
  /// APP_SPEC 12).
  Future<void> configure({required bool record});

  Stream<Interruption> get interruptions;

  /// Held while a session screen is open and in the foreground (APP_SPEC 11.5).
  Future<void> keepScreenOn(bool on);
}

class PlatformAudioHost implements AudioHost {
  @override
  Future<void> configure({required bool record}) async {
    final session = await AudioSession.instance;
    await session.configure(
      record
          ? const AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
              avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker,
              avAudioSessionMode: AVAudioSessionMode.spokenAudio,
              androidAudioAttributes: AndroidAudioAttributes(
                contentType: AndroidAudioContentType.speech,
                usage: AndroidAudioUsage.media,
              ),
              androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
            )
          // Speech; the system ducks us for short sounds rather than pausing (APP_SPEC 11.5).
          : const AudioSessionConfiguration.speech().copyWith(androidWillPauseWhenDucked: false),
    );
  }

  @override
  Stream<Interruption> get interruptions async* {
    final session = await AudioSession.instance;
    // Short sounds duck us without pausing: Android lowers the volume itself, because the
    // session doesn't ask to pause when ducked (see [configure]).
    yield* session.interruptionEventStream
        .where((e) => e.type != AudioInterruptionType.duck)
        .map((e) => e.begin ? Interruption.pauseBegin : Interruption.pauseEnd);
  }

  @override
  Future<void> keepScreenOn(bool on) => on ? WakelockPlus.enable() : WakelockPlus.disable();
}
