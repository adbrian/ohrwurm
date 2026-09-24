import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import '../library/library_controller.dart';
import '../mirror/mirror_controller.dart';
import '../mirror/mirror_screen.dart';
import '../mirror/recorder.dart';
import '../playback/clip_player.dart';
import '../settings/settings.dart';
import 'listen_controller.dart';
import 'listen_screen.dart';
import 'session_cards.dart';
import 'session_widgets.dart';
import 'sessions.dart';

/// Makes the player for a session screen, at the given clip speed. Tests pass a fake.
typedef PlayerFactory = ClipPlayer Function(double speed);

/// Disposes a player made by [PlayerFactory] when its screen closes.
typedef PlayerDisposer = Future<void> Function(ClipPlayer player);

/// The defaults of APP_SPEC 10.1, for [packIds].
SessionOptions defaultOptions(List<String> packIds) => SessionOptions(
  mode: SessionMode.listen,
  packIds: packIds,
  words: Words.all,
  focus: WordFocus.base,
  style: Style.statement,
  qaTranslate: QaTranslate.both,
  deckOrder: DeckOrder.sequential,
  cardMode: CardMode.looped,
  unheardFirst: false,
);

/// Makes the recorder for a Mirror screen. Tests pass a fake.
typedef RecorderFactory = Recorder Function();

/// Opens [opened] on its session screen — Listen or Mirror — and waits until the screen closes.
/// Returns true when the user asked to change the selection from the end card.
Future<bool> showSession(BuildContext context, OpenedSession opened) async {
  final db = context.read<AppDatabase>();
  final settings = context.read<AppSettings>();
  final makePlayer = context.read<PlayerFactory>();
  final disposePlayer = context.read<PlayerDisposer>();
  final sessions = context.read<Sessions>();
  final packs = {for (final p in context.read<LibraryController>().packs) p.packId: p};
  final names = packNames(opened.session.options.packIds, packs);
  final navigator = Navigator.of(context);
  final mirror = opened.session.options.mode == SessionMode.mirror;
  final makeRecorder = mirror ? context.read<RecorderFactory>() : null;
  final mic = mirror ? context.read<MicPermission>() : null;

  final players = [
    makePlayer(settings.speed),
    // Mirror plays the user's own recordings at 1×.
    if (mirror) makePlayer(1),
  ];
  final recorder = makeRecorder?.call();
  var changeSelection = false;
  try {
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          void onChangeSelection() {
            changeSelection = true;
            Navigator.of(routeContext).pop();
          }

          if (mirror) {
            return _Owned<MirrorController>(
              create: () => MirrorController(
                opened: opened,
                sessions: sessions,
                progress: db.progress,
                cardDao: db.cards,
                player: players[0],
                minePlayer: players[1],
                recorder: recorder!,
                mic: mic!,
              ),
              builder: (c) =>
                  MirrorScreen(controller: c, packs: names, onChangeSelection: onChangeSelection),
            );
          }
          return _Owned<ListenController>(
            create: () => ListenController(
              opened: opened,
              sessions: sessions,
              progress: db.progress,
              cardDao: db.cards,
              player: players[0],
              pauses: settings.pauses,
            ),
            builder: (c) =>
                ListenScreen(controller: c, packs: names, onChangeSelection: onChangeSelection),
          );
        },
      ),
    );
  } finally {
    for (final player in players) {
      await disposePlayer(player);
    }
    await recorder?.dispose();
  }
  return changeSelection;
}

/// Creates its controller when shown and disposes it when closed.
class _Owned<C extends ChangeNotifier> extends StatefulWidget {
  final C Function() create;
  final Widget Function(C controller) builder;

  const _Owned({super.key, required this.create, required this.builder});

  @override
  State<_Owned<C>> createState() => _OwnedState<C>();
}

class _OwnedState<C extends ChangeNotifier> extends State<_Owned<C>> {
  late final C _controller = widget.create();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

/// Creates a session with [options] (replacing the saved one) and shows it.
Future<bool> startSession(BuildContext context, SessionOptions options) async {
  final sessions = context.read<Sessions>();
  final session = await sessions.create(options);
  final opened = await sessions.open(session);
  if (!context.mounted) return false;
  return showSession(context, opened);
}
