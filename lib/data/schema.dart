/// Database schema, APP_SPEC section 6.
///
/// The primary device runs Android 10, whose SQLite is 3.22. Don't use features newer than
/// that in any SQL here or in the data-access classes: no upsert (`ON CONFLICT … DO UPDATE`,
/// 3.24), no window functions (3.25), no `RETURNING` (3.35). Desktop tests run a newer SQLite
/// and won't catch it.
library;

/// Version 1, exactly as in APP_SPEC 6.
///
/// `progress` has no foreign key and no cascade: progress is never deleted (CLAUDE.md, rule 5).
const schemaV1 = <String>[
  '''
CREATE TABLE packs (
  pack_id       TEXT PRIMARY KEY,
  level         TEXT NOT NULL,
  kind          TEXT NOT NULL,
  number        INTEGER NOT NULL,
  title         TEXT,
  card_count    INTEGER NOT NULL,
  audio_format  TEXT NOT NULL,
  available     INTEGER NOT NULL DEFAULT 1,
  created_at    TEXT NOT NULL,
  generated_at  TEXT NOT NULL
)''',
  '''
CREATE TABLE cards (
  card_id                 TEXT PRIMARY KEY,
  pack_id                 TEXT NOT NULL,
  key                     TEXT NOT NULL,
  type                    TEXT NOT NULL,
  added_at                TEXT NOT NULL,
  has_base_statement      INTEGER NOT NULL,
  has_base_qa             INTEGER NOT NULL,
  has_plural_statement    INTEGER NOT NULL,
  has_plural_qa           INTEGER NOT NULL,
  has_feminine_statement  INTEGER NOT NULL,
  has_feminine_qa         INTEGER NOT NULL,
  content_json            TEXT NOT NULL
)''',
  'CREATE INDEX idx_cards_pack ON cards(pack_id)',
  'CREATE INDEX idx_cards_key  ON cards(key)',
  '''
CREATE TABLE progress (
  key             TEXT PRIMARY KEY,
  times_heard     INTEGER NOT NULL DEFAULT 0,
  first_heard_at  TEXT,
  last_heard_at   TEXT,
  times_recorded  INTEGER NOT NULL DEFAULT 0
)''',
  '''
CREATE TABLE session (
  id               INTEGER PRIMARY KEY CHECK (id = 1),
  mode             TEXT NOT NULL,
  pack_ids_json    TEXT NOT NULL,
  words            TEXT NOT NULL,
  focus            TEXT NOT NULL,
  style            TEXT NOT NULL,
  qa_translate     TEXT NOT NULL,
  deck_order       TEXT NOT NULL,
  card_mode        TEXT NOT NULL,
  card_limit       INTEGER,
  unheard_first    INTEGER NOT NULL,
  card_order_json  TEXT NOT NULL,
  position         INTEGER NOT NULL DEFAULT 0,
  created_at       TEXT NOT NULL,
  last_opened_at   TEXT NOT NULL
)''',
];

/// Sort order everywhere (APP_SPEC 4.3): level, then kind (textbook before notebook), then
/// number. Levels `a1` < `a2` < `b1` < `b2` sort correctly as text. [table] is the alias or
/// name of the packs table in the query.
String packSortOrder([String table = 'packs']) =>
    "$table.level, CASE $table.kind WHEN 'textbook' THEN 0 ELSE 1 END, $table.number";
