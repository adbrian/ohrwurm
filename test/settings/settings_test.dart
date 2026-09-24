import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/settings/settings.dart';

import '../session/session_test_kit.dart';

void main() {
  test('defaults are those of APP_SPEC 11.4 and 14', () {
    final s = AppSettings(MemorySettingsStore());
    expect(s.pauses.afterWord.inMilliseconds, 800);
    expect(s.pauses.afterTranslation.inMilliseconds, 1000);
    expect(s.pauses.afterGermanSentence.inMilliseconds, 1500);
    expect(s.pauses.afterEnglishSentence.inMilliseconds, 800);
    expect(s.pauses.betweenCards.inMilliseconds, 2000);
    expect(s.speed, 1.0);
    expect(s.keepScreenOn, isTrue);
  });

  test('changes are saved and read back at the next launch', () async {
    final store = MemorySettingsStore();
    AppSettings(store)
      ..setPause(PauseKind.afterGermanSentence, 2500)
      ..setSpeed(0.75)
      ..setKeepScreenOn(false);
    final next = AppSettings(store);
    await next.load();
    expect(next.pauses.afterGermanSentence.inMilliseconds, 2500);
    expect(next.speed, 0.75);
    expect(next.keepScreenOn, isFalse);
  });

  test('pauses stay in range; only the three speeds are accepted', () {
    final s = AppSettings(MemorySettingsStore())
      ..setPause(PauseKind.betweenCards, 99999)
      ..setSpeed(2.0);
    expect(s.pauseMs(PauseKind.betweenCards), AppSettings.maxPauseMs);
    expect(s.speed, 1.0);
  });
}
