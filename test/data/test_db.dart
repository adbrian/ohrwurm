import 'package:ohrwurm/data/app_database.dart';
import 'package:ohrwurm/data/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// A clock tests can move.
class FakeClock {
  DateTime now = DateTime.utc(2026, 9, 24, 8);

  DateTime call() => now;

  void advance([Duration by = const Duration(minutes: 1)]) => now = now.add(by);
}

/// Opens a fresh in-memory database. Close it in tearDown.
Future<AppDatabase> openTestDatabase(FakeClock clock) {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfiNoIsolate,
    path: inMemoryDatabasePath,
    clock: clock.call,
  );
}

PackInput packInput(
  String packId, {
  String? level,
  String? kind,
  int? number,
  String? title,
  String generatedAt = '2026-09-01T10:00:00Z',
}) {
  final match = RegExp(r'^([ab][12])_(k|nb)(\d+)$').firstMatch(packId)!;
  return PackInput(
    packId: packId,
    level: level ?? match[1]!,
    kind: kind ?? (match[2] == 'k' ? 'textbook' : 'notebook'),
    number: number ?? int.parse(match[3]!),
    title: title,
    audioFormat: 'opus',
    generatedAt: generatedAt,
  );
}

CardRow card(
  String packId,
  String key, {
  String type = 'noun',
  Set<ExampleSlot> examples = const {ExampleSlot.baseStatement},
}) =>
    CardRow(
      cardId: '${packId}__$key',
      packId: packId,
      key: key,
      type: type,
      addedAt: '2026-09-01',
      examples: examples,
      contentJson: '{"key":"$key"}',
    );
