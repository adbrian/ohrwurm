import 'dart:convert';
import 'dart:io';

import 'package:ohrwurm/cards/card_content.dart';

/// A fixture pack's card by key, as `content_json` stores it: the manifest's card, whole.
String fixtureCardJson(String packId, String key) {
  final manifest = jsonDecode(
    File('test/fixtures/packs/$packId/manifest.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cards = (manifest['cards'] as List).cast<Map<String, dynamic>>();
  return jsonEncode(cards.singleWhere((c) => c['key'] == key));
}

CardContent fixtureCard(String packId, String key) =>
    CardContent.fromJson(fixtureCardJson(packId, key));
