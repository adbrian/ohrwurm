import '../cards/card_content.dart';
import '../cards/recipe.dart';
import '../data/card_dao.dart';
import '../data/models.dart';
import '../data/pack_dao.dart';
import '../packs/pack_storage.dart';
import '../playback/listen_engine.dart';

/// Finds each clip's URI. Clips are read in place, as `content://` URIs (APP_SPEC 5.1); each
/// pack folder is listed **once** and its names matched, never looked up one by one (A0
/// finding 1).
abstract class ClipResolver {
  /// For each of [packIds], its files by name → URI. A pack whose folder can't be listed maps to
  /// an empty map: its clips then fail to play, which the Listen card reports (STATUS,
  /// 2026-09-24).
  Future<Map<String, Map<String, String>>> resolve(Iterable<String> packIds);
}

class StorageClipResolver implements ClipResolver {
  final PackStorage storage;

  /// The root folder's URI, read when [resolve] runs.
  final String? Function() root;

  StorageClipResolver({required this.storage, required this.root});

  @override
  Future<Map<String, Map<String, String>>> resolve(Iterable<String> packIds) async {
    final wanted = packIds.toSet();
    final out = {for (final id in wanted) id: <String, String>{}};
    final rootUri = root();
    if (rootUri == null) return out;
    try {
      final folders = await storage.list(rootUri);
      for (final folder in folders.where((f) => f.isDir && wanted.contains(f.name))) {
        final files = await storage.list(folder.uri);
        out[folder.name] = {
          for (final f in files)
            if (!f.isDir) f.name: f.uri,
        };
      }
    } catch (_) {
      // Unreadable: the clips fail to play, and the card says so.
    }
    return out;
  }
}

/// A clip that isn't in its pack folder any more. Playing it fails.
String missingClipUri(String packId, String name) => 'missing:$packId/$name';

/// One card of a session: its row, its content, and its URIs.
class SessionCard {
  final CardRow row;
  final CardContent content;
  final Map<String, String> _clips;

  SessionCard(this.row, this._clips) : content = CardContent.fromJson(row.contentJson);

  String get packId => row.packId;

  String clipUri(Line line) => _clips[line.audio] ?? missingClipUri(packId, line.audio);
}

/// A session's cards, opened for playing.
class OpenedSession {
  final Session session;

  /// The cards still present, in the session's order.
  final List<SessionCard> cards;

  /// The position in [cards]: the saved position, less the cards before it that are gone.
  final int position;

  /// How many of the session's cards are gone: removed from their packs, or in packs that are
  /// unavailable.
  final int dropped;

  const OpenedSession({
    required this.session,
    required this.cards,
    required this.position,
    required this.dropped,
  });

  /// More than half the cards are gone: go to setup with an explanation instead (APP_SPEC 10.2).
  bool get mostlyGone => dropped * 2 > session.cardOrder.length;
}

/// Loads a session's cards. Card ids that no longer exist, or whose pack is unavailable, are
/// dropped (APP_SPEC 10.2).
Future<OpenedSession> openSession(
  Session session, {
  required CardDao cards,
  required PackDao packs,
  required ClipResolver clips,
}) async {
  final rows = await cards.getCards(session.cardOrder);
  final available = {
    for (final p in await packs.listPacks())
      if (p.available) p.packId,
  };
  final kept = <CardRow>[];
  var position = session.position;
  for (final (i, id) in session.cardOrder.indexed) {
    final row = rows[id];
    if (row != null && available.contains(row.packId)) {
      kept.add(row);
    } else if (i < session.position) {
      position--;
    }
  }
  final uris = await clips.resolve({for (final r in kept) r.packId});
  return OpenedSession(
    session: session,
    cards: [for (final r in kept) SessionCard(r, uris[r.packId] ?? const {})],
    position: position.clamp(0, kept.length),
    dropped: session.cardOrder.length - kept.length,
  );
}

/// The Listen engine's view of a session: each card's recipe as steps (APP_SPEC 9, 11).
class ListenCards implements ListenDeck {
  final List<SessionCard> cards;
  final Recipe recipe;
  final QaTranslate qaTranslate;
  final List<List<RecipeLine>> lines;

  ListenCards(this.cards, this.recipe, this.qaTranslate)
    : lines = [
        // Setup only admits cards that have the recipe's examples (APP_SPEC 9); a card whose
        // content disagrees with its flags plays its word and translation.
        for (final c in cards)
          recipe.lines(c.content, qaTranslate) ?? Recipe(const []).lines(c.content, qaTranslate)!,
      ];

  @override
  int get length => cards.length;

  @override
  String key(int index) => cards[index].row.key;

  @override
  List<Step> steps(int index) => [
    for (final l in lines[index]) Step(cards[index].clipUri(l.line), l.role),
  ];
}
