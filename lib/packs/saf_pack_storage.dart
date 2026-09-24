import 'dart:convert';

import 'package:saf_stream/saf_stream.dart';
import 'package:saf_util/saf_util.dart';

import 'pack_storage.dart';

/// [PackStorage] through the Storage Access Framework: the folder is read in place, and clips
/// are `content://` URIs (APP_SPEC 5.1, A0).
class SafPackStorage implements PackStorage {
  final _saf = SafUtil();
  final _stream = SafStream();

  /// Returns the **tree** URI (`…/tree/<id>`), which is what holds the permission.
  /// `pickDirectory` returns `…/tree/<id>/document/<id>` (A0 finding 4).
  @override
  Future<String?> pickFolder({String? initial}) async {
    final dir = await _saf.pickDirectory(
      initialUri: initial == null ? null : rootDocumentUri(initial),
      persistablePermission: true,
    );
    return dir == null ? null : treeUri(dir.uri);
  }

  @override
  Future<RootAccess> checkRoot(String root) async {
    try {
      // saf_util compares permissions by document id, so it's given the document form.
      final doc = rootDocumentUri(root);
      if (!await _saf.hasPersistedPermission(doc)) return RootAccess.denied;
      final stat = await _saf.stat(doc, true);
      return stat == null ? RootAccess.missing : RootAccess.ok;
    } catch (_) {
      return RootAccess.denied;
    }
  }

  @override
  Future<List<StorageEntry>> list(String dirUri) async {
    final files = await _saf.list(rootDocumentUri(dirUri));
    return [for (final f in files) StorageEntry(name: f.name, uri: f.uri, isDir: f.isDir)];
  }

  @override
  Future<String> readText(String fileUri) async =>
      utf8.decode(await _stream.readFileBytes(fileUri));

  /// `content://…/tree/primary%3ADownload%2Fohrwurm-packs` → `Download/ohrwurm-packs`.
  @override
  String describe(String root) {
    final id = Uri.decodeComponent(treeUri(root).split('/tree/').last);
    final colon = id.indexOf(':');
    final volume = colon < 0 ? '' : id.substring(0, colon);
    final path = colon < 0 ? id : id.substring(colon + 1);
    if (volume == 'primary' || volume.isEmpty) return path;
    return '$volume/$path';
  }

  /// The tree URI of [uri], dropping any `/document/…` part.
  static String treeUri(String uri) => uri.split('/document/').first;

  /// The document URI of a tree's root folder. Other document URIs are returned unchanged.
  static String rootDocumentUri(String uri) {
    if (uri.contains('/document/')) return uri;
    return '$uri/document/${uri.split('/tree/').last}';
  }
}
