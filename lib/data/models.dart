/// Rows of the tables in APP_SPEC 6, as plain Dart values.
library;

/// A pack as found on disk, ready to be written by `PackDao.replacePack`. Fields come from the
/// manifest (APP_SPEC 4.3).
class PackInput {
  final String packId;
  final String level;
  final String kind;
  final int number;
  final String? title;
  final String audioFormat;
  final String generatedAt;

  const PackInput({
    required this.packId,
    required this.level,
    required this.kind,
    required this.number,
    this.title,
    required this.audioFormat,
    required this.generatedAt,
  });
}

/// A row of `packs`.
class Pack {
  final String packId;
  final String level;
  final String kind;
  final int number;
  final String? title;
  final int cardCount;
  final String audioFormat;
  final bool available;
  final String createdAt;
  final String generatedAt;

  const Pack({
    required this.packId,
    required this.level,
    required this.kind,
    required this.number,
    this.title,
    required this.cardCount,
    required this.audioFormat,
    required this.available,
    required this.createdAt,
    required this.generatedAt,
  });

  factory Pack.fromRow(Map<String, Object?> row) => Pack(
        packId: row['pack_id'] as String,
        level: row['level'] as String,
        kind: row['kind'] as String,
        number: row['number'] as int,
        title: row['title'] as String?,
        cardCount: row['card_count'] as int,
        audioFormat: row['audio_format'] as String,
        available: row['available'] == 1,
        createdAt: row['created_at'] as String,
        generatedAt: row['generated_at'] as String,
      );
}

/// A form and kind of example a recipe can require (APP_SPEC 4.7, 9). Each has a `has_*` flag
/// in `cards`.
enum ExampleSlot {
  baseStatement('has_base_statement'),
  baseQa('has_base_qa'),
  pluralStatement('has_plural_statement'),
  pluralQa('has_plural_qa'),
  feminineStatement('has_feminine_statement'),
  feminineQa('has_feminine_qa');

  const ExampleSlot(this.column);

  final String column;
}

/// A row of `cards`.
class CardRow {
  final String cardId;
  final String packId;
  final String key;
  final String type;
  final String addedAt;

  /// The slots whose `has_*` flag is set.
  final Set<ExampleSlot> examples;

  /// The card as it appears in the manifest.
  final String contentJson;

  const CardRow({
    required this.cardId,
    required this.packId,
    required this.key,
    required this.type,
    required this.addedAt,
    required this.examples,
    required this.contentJson,
  });

  factory CardRow.fromRow(Map<String, Object?> row) => CardRow(
        cardId: row['card_id'] as String,
        packId: row['pack_id'] as String,
        key: row['key'] as String,
        type: row['type'] as String,
        addedAt: row['added_at'] as String,
        examples: {
          for (final slot in ExampleSlot.values)
            if (row[slot.column] == 1) slot,
        },
        contentJson: row['content_json'] as String,
      );

  Map<String, Object?> toRow() => {
        'card_id': cardId,
        'pack_id': packId,
        'key': key,
        'type': type,
        'added_at': addedAt,
        for (final slot in ExampleSlot.values) slot.column: examples.contains(slot) ? 1 : 0,
        'content_json': contentJson,
      };
}

/// A row of `progress`.
class Progress {
  final String key;
  final int timesHeard;
  final String? firstHeardAt;
  final String? lastHeardAt;
  final int timesRecorded;

  const Progress({
    required this.key,
    required this.timesHeard,
    this.firstHeardAt,
    this.lastHeardAt,
    required this.timesRecorded,
  });

  factory Progress.fromRow(Map<String, Object?> row) => Progress(
        key: row['key'] as String,
        timesHeard: row['times_heard'] as int,
        firstHeardAt: row['first_heard_at'] as String?,
        lastHeardAt: row['last_heard_at'] as String?,
        timesRecorded: row['times_recorded'] as int,
      );
}

/// A pack's distinct word keys, and how many of them have been heard at least once (APP_SPEC 7).
class PackProgress {
  final int heard;
  final int total;

  const PackProgress({required this.heard, required this.total});

  @override
  bool operator ==(Object other) =>
      other is PackProgress && other.heard == heard && other.total == total;

  @override
  int get hashCode => Object.hash(heard, total);

  @override
  String toString() => 'PackProgress($heard / $total)';
}

// Session options (APP_SPEC 10.1). Each value's name is what the database stores.

enum SessionMode { listen, mirror }

enum Words { all, noun, verb, other }

enum Focus { base, plural, feminine }

enum Style { statement, qa }

enum QaTranslate { both, question }

enum DeckOrder { sequential, shuffled }

enum CardMode { looped, continuous }

/// The choices made in session setup.
class SessionOptions {
  final SessionMode mode;

  /// In selection order.
  final List<String> packIds;
  final Words words;
  final Focus focus;
  final Style style;
  final QaTranslate qaTranslate;
  final DeckOrder deckOrder;
  final CardMode cardMode;

  /// Null means no limit.
  final int? cardLimit;
  final bool unheardFirst;

  const SessionOptions({
    required this.mode,
    required this.packIds,
    required this.words,
    required this.focus,
    required this.style,
    required this.qaTranslate,
    required this.deckOrder,
    required this.cardMode,
    this.cardLimit,
    required this.unheardFirst,
  });
}

/// The `session` row: options, the resolved card order and the position in it.
class Session {
  final SessionOptions options;
  final List<String> cardOrder;
  final int position;
  final String createdAt;
  final String lastOpenedAt;

  const Session({
    required this.options,
    required this.cardOrder,
    required this.position,
    required this.createdAt,
    required this.lastOpenedAt,
  });
}
