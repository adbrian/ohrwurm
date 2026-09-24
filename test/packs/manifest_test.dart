import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohrwurm/data/models.dart';
import 'package:ohrwurm/packs/manifest.dart';

import 'directory_pack_storage.dart';
import 'manifest_breakages.dart';

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

const k02 = 'test/fixtures/packs/a1_k02/manifest.json';
const nb01 = 'test/fixtures/packs/a1_nb01/manifest.json';
const k03 = 'test/fixtures/packs/a1_k03/manifest.json';

/// The real pipeline pack, Kapitel 1 (test/fixtures/real/README.md).
const k01 = 'test/fixtures/real/a1_k01_manifest.json';

void main() {
  final validator = ManifestValidator(schemaJson);

  group('validator', () {
    for (final path in [k02, nb01, k03, k01]) {
      test('accepts $path', () => expect(validator.errors(readJson(path)), isEmpty));
    }

    final valid = readJson(k02);
    for (final name in breakages.keys) {
      test('rejects: $name', () => expect(validator.errors(broken(valid, name)), isNotEmpty));
    }

    test('does not assert date-time format', () {
      final m = readJson(k02)..['generated_at'] = 'last Tuesday';
      expect(validator.errors(m), isEmpty);
    });
  });

  group('reader', () {
    test('reads the pack fields', () {
      final pack = PackManifest.read(readJson(k02)).pack;
      expect(pack.packId, 'a1_k02');
      expect(pack.level, 'a1');
      expect(pack.kind, 'textbook');
      expect(pack.number, 2);
      expect(pack.title, 'Freunde, Kollegen und ich');
      expect(pack.audioFormat, 'opus');
      expect(pack.generatedAt, '2026-09-23T14:30:00Z');
    });

    test('a pack without a title has a null title', () {
      expect(PackManifest.read(readJson(nb01)).pack.title, isNull);
    });

    test('reads cards in manifest order with their example flags', () {
      final cards = PackManifest.read(readJson(k02)).cards;
      expect([for (final c in cards) c.key], ['der_freund', 'singen', 'heissen', 'gern']);
      expect(cards.first.cardId, 'a1_k02__der_freund');
      expect(cards.first.packId, 'a1_k02');
      expect(cards.first.type, 'noun');
      expect(cards.first.examples, {
        ExampleSlot.baseStatement,
        ExampleSlot.baseQa,
        ExampleSlot.pluralStatement,
        ExampleSlot.feminineStatement,
      });
      expect(cards.last.examples, {ExampleSlot.baseQa});
    });

    test('content_json is the card as it appears in the manifest', () {
      final manifest = readJson(k02);
      final cards = PackManifest.read(manifest).cards;
      expect(jsonDecode(cards[2].contentJson), (manifest['cards'] as List)[2]);
    });

    test('collects every referenced clip', () {
      final clips = PackManifest.read(readJson(k02)).clips;
      final onDisk = {
        for (final f in Directory('test/fixtures/packs/a1_k02').listSync())
          f.uri.pathSegments.last,
      }..remove('manifest.json');
      expect(clips, onDisk);
    });

    test('reads the real pack', () {
      final manifest = PackManifest.read(readJson(k01));
      expect(manifest.pack.packId, 'a1_k01');
      expect(manifest.pack.title, 'Guten Tag!');
      expect(manifest.cards, hasLength(200));
      expect(manifest.clips, isNotEmpty);
    });
  });

  group('checkManifest', () {
    ManifestCheck check(String path, {String? folder, Set<String>? clips, String? text}) {
      final json = text ?? File(path).readAsStringSync();
      return checkManifest(
        schemaJson: schemaJson,
        folderName: folder ?? path.split('/').reversed.skip(1).first,
        manifestText: json,
        clipNames: clips ??
            {for (final f in Directory(File(path).parent.path).listSync()) f.uri.pathSegments.last},
      );
    }

    test('accepts a valid pack', () {
      final result = check(k02);
      expect(result.rejection, isNull);
      expect(result.manifest!.cards, hasLength(4));
    });

    test('rejects text that is not JSON', () {
      expect(check(k02, text: 'not json').rejection, isA<ManifestUnreadable>());
    });

    test('rejects JSON that breaks the schema, with its errors', () {
      final result = check(k02, text: jsonEncode(broken(readJson(k02), 'unknown level')));
      expect((result.rejection! as SchemaInvalid).errors, isNotEmpty);
    });

    test('rejects a pack_id that is not the folder name', () {
      final result = check(k02, folder: 'a1_k05');
      expect((result.rejection! as FolderMismatch).packId, 'a1_k02');
    });

    test('rejects an audio format it cannot play', () {
      final m = readJson(k02)..['audio_format'] = 'mp3';
      expect((check(k02, text: jsonEncode(m)).rejection! as UnplayableAudio).format, 'mp3');
    });

    test('rejects missing clips, listing them', () {
      final result = check(k03);
      expect((result.rejection! as ClipsMissing).missing, ['a1_k03__die_stadt__ex1_src.ogg']);
      expect(result.pack!.packId, 'a1_k03');
    });

    test('the real pack passes with all its clips present', () {
      final clips = PackManifest.read(readJson(k01)).clips;
      expect(check(k01, folder: 'a1_k01', clips: clips).rejection, isNull);
    });
  });
}
