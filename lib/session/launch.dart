import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/app_database.dart';
import '../data/models.dart';
import '../library/library_controller.dart';
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

/// Opens [opened] on its session screen and waits until the screen closes. Returns true when the
/// user asked to change the selection from the end card.
Future<bool> showSession(BuildContext context, OpenedSession opened) async {
  final db = context.read<AppDatabase>();
  final settings = context.read<AppSettings>();
  final makePlayer = context.read<PlayerFactory>();
  final disposePlayer = context.read<PlayerDisposer>();
  final sessions = context.read<Sessions>();
  final packs = {for (final p in context.read<LibraryController>().packs) p.packId: p};
  final names = packNames(opened.session.options.packIds, packs);
  final navigator = Navigator.of(context);

  final player = makePlayer(settings.speed);
  var changeSelection = false;
  try {
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (routeContext) => _OwnedListenScreen(
          create: () => ListenController(
            opened: opened,
            sessions: sessions,
            progress: db.progress,
            cardDao: db.cards,
            player: player,
            pauses: settings.pauses,
          ),
          packs: names,
          onChangeSelection: () {
            changeSelection = true;
            Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
  } finally {
    await disposePlayer(player);
  }
  return changeSelection;
}

/// Creates its controller when shown and disposes it when closed.
class _OwnedListenScreen extends StatefulWidget {
  final ListenController Function() create;
  final String packs;
  final VoidCallback onChangeSelection;

  const _OwnedListenScreen({
    required this.create,
    required this.packs,
    required this.onChangeSelection,
  });

  @override
  State<_OwnedListenScreen> createState() => _OwnedListenScreenState();
}

class _OwnedListenScreenState extends State<_OwnedListenScreen> {
  late final ListenController _controller = widget.create();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenScreen(
    controller: _controller,
    packs: widget.packs,
    onChangeSelection: widget.onChangeSelection,
  );
}

/// Creates a session with [options] (replacing the saved one) and shows it.
Future<bool> startSession(BuildContext context, SessionOptions options) async {
  final sessions = context.read<Sessions>();
  final session = await sessions.create(options);
  final opened = await sessions.open(session);
  if (!context.mounted) return false;
  return showSession(context, opened);
}
