import 'dart:convert';

import 'package:json_schema/json_schema.dart';

import '../data/models.dart';

/// Audio formats this build can play (APP_SPEC 4.3).
const playableAudioFormats = {'opus'};

/// Validates manifests against `schema/manifest.v2.schema.json` (APP_SPEC 4.1).
///
/// `format` is not asserted: that is the draft 2020-12 default, and how the pipeline and
/// `tool/make_fixture_pack.py` validate (STATUS, 2026-09-24).
class ManifestValidator {
  final JsonSchema _schema;

  ManifestValidator(String schemaJson) : _schema = JsonSchema.create(jsonDecode(schemaJson));

  /// The validation errors, empty when [manifest] is valid.
  List<String> errors(Object? manifest) => [
        for (final e in _schema.validate(manifest, validateFormats: false).errors) e.toString(),
      ];
}

/// A valid manifest, read into the rows `PackDao.replacePack` writes.
class PackManifest {
  final PackInput pack;

  /// In manifest order.
  final List<CardRow> cards;

  /// Every clip filename the manifest references.
  final Set<String> clips;

  const PackManifest({required this.pack, required this.cards, required this.clips});

  /// Reads a manifest that has passed [ManifestValidator].
  factory PackManifest.read(Map<String, dynamic> m) {
    final packId = m['pack_id'] as String;
    final clips = <String>{};
    void line(Object? l) {
      if (l is Map) clips.add(l['audio'] as String);
    }

    final cards = <CardRow>[];
    for (final c in (m['cards'] as List).cast<Map<String, dynamic>>()) {
      line(c['word']);
      line(c['translation']);
      final examples = <ExampleSlot>{};
      for (final e in (c['examples'] as List).cast<Map<String, dynamic>>()) {
        examples.add(_slot(e['form'] as String, e['kind'] as String));
        line(e['source']);
        line(e['target']);
        for (final part in [e['question'], e['answer']]) {
          if (part is Map) {
            line(part['source']);
            line(part['target']);
          }
        }
      }
      cards.add(CardRow(
        cardId: c['id'] as String,
        packId: packId,
        key: c['key'] as String,
        type: c['type'] as String,
        addedAt: c['added_at'] as String,
        examples: examples,
        contentJson: jsonEncode(c),
      ));
    }

    return PackManifest(
      pack: PackInput(
        packId: packId,
        level: m['level'] as String,
        kind: m['kind'] as String,
        number: m['number'] as int,
        title: m['title'] as String?,
        audioFormat: m['audio_format'] as String,
        generatedAt: m['generated_at'] as String,
      ),
      cards: cards,
      clips: clips,
    );
  }

  static ExampleSlot _slot(String form, String kind) => switch ((form, kind)) {
        ('base', 'statement') => ExampleSlot.baseStatement,
        ('base', 'qa') => ExampleSlot.baseQa,
        ('plural', 'statement') => ExampleSlot.pluralStatement,
        ('plural', 'qa') => ExampleSlot.pluralQa,
        ('feminine', 'statement') => ExampleSlot.feminineStatement,
        ('feminine', 'qa') => ExampleSlot.feminineQa,
        _ => throw ArgumentError('Unknown example form/kind: $form/$kind'),
      };
}

/// Why a pack was rejected (APP_SPEC 5.2, step 2).
sealed class Rejection {
  const Rejection();
}

/// `manifest.json` couldn't be read, or isn't JSON.
class ManifestUnreadable extends Rejection {
  const ManifestUnreadable();
}

/// The manifest doesn't match the schema.
class SchemaInvalid extends Rejection {
  final List<String> errors;

  const SchemaInvalid(this.errors);
}

/// `pack_id` isn't the folder's name.
class FolderMismatch extends Rejection {
  final String packId;

  const FolderMismatch(this.packId);
}

class UnplayableAudio extends Rejection {
  final String format;

  const UnplayableAudio(this.format);
}

class ClipsMissing extends Rejection {
  /// Sorted.
  final List<String> missing;

  const ClipsMissing(this.missing);
}

/// The pack passed its checks but writing it to the database failed; nothing was changed.
class SaveFailed extends Rejection {
  const SaveFailed();
}

/// The result of checking one pack folder: a [PackManifest] or a [Rejection].
class ManifestCheck {
  final PackManifest? manifest;
  final Rejection? rejection;

  const ManifestCheck.accepted(PackManifest this.manifest) : rejection = null;

  const ManifestCheck.rejected(Rejection this.rejection) : manifest = null;
}

/// Runs the checks of APP_SPEC 5.2, step 2, on one pack folder. Any failure rejects the whole
/// pack. [clipNames] are the names of the files in the folder, from a single listing (A0
/// finding 1). Pure, so it can run in another isolate.
ManifestCheck checkManifest({
  required String schemaJson,
  required String folderName,
  required String manifestText,
  required Set<String> clipNames,
}) {
  final Object? json;
  try {
    json = jsonDecode(manifestText);
  } on FormatException {
    return const ManifestCheck.rejected(ManifestUnreadable());
  }
  final errors = ManifestValidator(schemaJson).errors(json);
  if (errors.isNotEmpty) return ManifestCheck.rejected(SchemaInvalid(errors));

  final manifest = PackManifest.read(json as Map<String, dynamic>);
  final pack = manifest.pack;
  if (pack.packId != folderName) return ManifestCheck.rejected(FolderMismatch(pack.packId));
  if (!playableAudioFormats.contains(pack.audioFormat)) {
    return ManifestCheck.rejected(UnplayableAudio(pack.audioFormat));
  }
  final missing = manifest.clips.where((c) => !clipNames.contains(c)).toList()..sort();
  if (missing.isNotEmpty) return ManifestCheck.rejected(ClipsMissing(missing));
  return ManifestCheck.accepted(manifest);
}
