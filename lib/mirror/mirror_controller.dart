import 'dart:async';

import 'package:flutter/foundation.dart';

import '../cards/card_content.dart';
import '../data/card_dao.dart';
import '../data/models.dart';
import '../data/progress_dao.dart';
import '../playback/clip_player.dart';
import '../session/session_cards.dart';
import '../session/sessions.dart';
import 'recorder.dart';

/// One Mirror box: a German line with its English, which can be played and recorded
/// (APP_SPEC 12, DESIGN 7).
class MirrorBox {
  final Pair pair;

  /// *Question* or *Answer* with Q&A style; null for statements.
  final String? label;

  const MirrorBox(this.pair, [this.label]);
}

/// The boxes for [card] (APP_SPEC 12): with statements, the first two base statements (one box
/// if only one exists); with Q&A, the base question and the base answer.
List<MirrorBox> mirrorBoxes(CardContent card, Style style) {
  switch (style) {
    case Style.statement:
      return [
        for (final e in card.examples.whereType<StatementExample>().where((e) => e.form == 'base'))
          MirrorBox(e.pair),
      ].take(2).toList();
    case Style.qa:
      final qa = card.examples.whereType<QaExample>().where((e) => e.form == 'base').firstOrNull;
      if (qa == null) return const [];
      return [MirrorBox(qa.question, 'question'), MirrorBox(qa.answer, 'answer')];
  }
}

/// What a box is doing.
enum BoxActivity { idle, playingGerman, playingMine, recording }

/// A Mirror session on screen: no auto-play, no auto-advance; swipe moves between cards
/// (APP_SPEC 12). Any play or record action cancels whatever else is playing or recording, with
/// the same generation rule as the Listen engine: **check the generation after every `await`**
/// (APP_SPEC 11.3).
class MirrorController extends ChangeNotifier {
  final Sessions sessions;
  final ProgressDao progress;
  final CardDao cardDao;

  /// Plays the pack's clips, at the speed setting.
  final ClipPlayer player;

  /// Plays the user's recordings, always at 1×: speed is a setting for clips (APP_SPEC 14).
  final ClipPlayer minePlayer;
  final Recorder recorder;
  final MicPermission mic;

  MirrorController({
    required OpenedSession opened,
    required this.sessions,
    required this.progress,
    required this.cardDao,
    required this.player,
    required this.minePlayer,
    required this.recorder,
    required this.mic,
  }) : _opened = opened,
       _position = opened.position {
    _loadAlsoIn();
  }

  OpenedSession _opened;
  int _position;

  Session get session => _opened.session;
  int get position => _position;
  int get length => _opened.cards.length;
  bool get atEnd => _position >= length;
  SessionCard? get card => atEnd ? null : _opened.cards[_position];

  List<MirrorBox> get boxes => atEnd ? const [] : mirrorBoxes(card!.content, session.options.style);

  /// The generation: bumped by every action, so work from an older action returns when it wakes.
  int _gen = 0;
  bool _disposed = false;

  int? _activeBox;
  BoxActivity _activity = BoxActivity.idle;

  /// The box that is playing or recording, and what it's doing.
  int? get activeBox => _activeBox;
  BoxActivity get activity => _activity;

  final Map<int, String> _recordings = {};

  /// Whether box [i] has a recording to play back (*Play mine*).
  bool hasRecording(int i) => _recordings.containsKey(i);

  int _elapsed = 0;
  Timer? _ticker;

  /// Seconds recorded so far, for the counter beside *Stop*.
  int get elapsed => _elapsed;

  MicAccess? _micRefused;
  int? _micRefusedBox;

  /// When the microphone was refused on box [i]'s Record, how (to explain it there).
  MicAccess? micRefusedIn(int i) => _micRefusedBox == i ? _micRefused : null;

  List<String> _alsoIn = const [];
  List<String> get alsoIn => _alsoIn;

  /// Plays box [i]'s German clip.
  Future<void> play(int i) async {
    final myGen = await _cancel();
    if (myGen != _gen) return;
    await _playUri(
      player,
      i,
      BoxActivity.playingGerman,
      card!.clipUri(boxes[i].pair.source),
      myGen,
    );
  }

  /// Plays the user's recording for box [i].
  Future<void> playMine(int i) async {
    final path = _recordings[i];
    if (path == null) return;
    final myGen = await _cancel();
    if (myGen != _gen) return;
    await _playUri(minePlayer, i, BoxActivity.playingMine, Uri.file(path).toString(), myGen);
  }

  Future<void> _playUri(
    ClipPlayer through,
    int i,
    BoxActivity activity,
    String uri,
    int myGen,
  ) async {
    _set(i, activity);
    try {
      await through.play(uri);
    } catch (_) {
      // The clip couldn't be played; the box simply stops.
    }
    if (myGen != _gen) return;
    _set(null, BoxActivity.idle);
  }

  /// Records box [i]. The microphone is asked for on the first Record (APP_SPEC 12).
  Future<void> record(int i) async {
    final myGen = await _cancel();
    if (myGen != _gen) return;
    final access = await mic.request();
    if (myGen != _gen) return;
    if (access != MicAccess.granted) {
      _micRefused = access;
      _micRefusedBox = i;
      notifyListeners();
      return;
    }
    _micRefused = null;
    _micRefusedBox = null;
    await recorder.start();
    if (myGen != _gen) {
      // Cancelled while starting: throw that recording away.
      await recorder.cancel();
      return;
    }
    _elapsed = 0;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      notifyListeners();
    });
    _set(i, BoxActivity.recording);
  }

  /// *Stop*: the recording is kept for *Play mine*, replacing the box's last attempt, and counted
  /// (APP_SPEC 12).
  Future<void> stopRecording() async {
    final box = _activeBox;
    if (_activity != BoxActivity.recording || box == null) return;
    final myGen = ++_gen;
    _stopTicker();
    _set(null, BoxActivity.idle);
    final path = await recorder.stop();
    if (path == null) return;
    final old = _recordings[box];
    if (old != null) unawaited(recorder.delete(old));
    if (myGen != _gen || _disposed) {
      // The card was left meanwhile: the recording goes with it.
      unawaited(recorder.delete(path));
      return;
    }
    _recordings[box] = path;
    unawaited(progress.incrementRecorded(card!.row.key));
    notifyListeners();
  }

  Future<void> openSettings() => mic.openSettings();

  /// Swipe: the next card. The card's recordings are deleted (APP_SPEC 12).
  Future<void> swipe() async {
    if (atEnd) return;
    await _leaveCard();
    if (_disposed) return;
    _position++;
    unawaited(sessions.savePosition(_position));
    _loadAlsoIn();
    notifyListeners();
  }

  /// *Restart* on the end card (APP_SPEC 10.3).
  Future<void> restart() => _replace(sessions.restart);

  /// *Reshuffle* on the end card (APP_SPEC 10.3).
  Future<void> reshuffle() => _replace(sessions.reshuffle);

  Future<void> _replace(Future<Session> Function(Session) change) async {
    await _leaveCard();
    final updated = await change(session);
    if (_disposed) return;
    final byId = {for (final c in _opened.cards) c.row.cardId: c};
    _opened = OpenedSession(
      session: updated,
      cards: [
        for (final id in updated.cardOrder)
          if (byId[id] != null) byId[id]!,
      ],
      position: 0,
      dropped: 0,
    );
    _position = 0;
    _loadAlsoIn();
    notifyListeners();
  }

  /// The app went to the background: stop playing and recording. Recordings are kept until the
  /// card is left.
  Future<void> pause() async {
    await _cancel();
  }

  /// Stops whatever is playing or recording, and returns the new generation.
  Future<int> _cancel() async {
    final myGen = ++_gen;
    _stopTicker();
    final wasRecording = _activity == BoxActivity.recording;
    _set(null, BoxActivity.idle);
    unawaited(player.stop());
    unawaited(minePlayer.stop());
    if (wasRecording) await recorder.cancel();
    return myGen;
  }

  Future<void> _leaveCard() async {
    await _cancel();
    final paths = _recordings.values.toList();
    _recordings.clear();
    _micRefused = null;
    _micRefusedBox = null;
    for (final path in paths) {
      await recorder.delete(path);
    }
  }

  Future<void> _loadAlsoIn() async {
    final c = card;
    _alsoIn = const [];
    if (c == null) return;
    final at = _position;
    final packs = await cardDao.alsoIn(c.row.key, c.packId);
    if (_disposed || at != _position) return;
    _alsoIn = packs;
    notifyListeners();
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _set(int? box, BoxActivity activity) {
    _activeBox = box;
    _activity = activity;
    if (!_disposed) notifyListeners();
  }

  /// Leaving the screen leaves the card: its recordings are deleted.
  Future<void> close() => _leaveCard();

  @override
  void dispose() {
    _disposed = true;
    _gen++;
    _stopTicker();
    super.dispose();
  }
}
