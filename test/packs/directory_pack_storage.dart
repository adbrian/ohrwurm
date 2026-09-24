import 'dart:io';

import 'package:ohrwurm/packs/pack_storage.dart';
import 'package:path/path.dart' as p;

/// [PackStorage] over plain directories, so rescan can be tested on desktop. URIs are paths.
class DirectoryPackStorage implements PackStorage {
  /// Returned by [pickFolder]; null is a cancelled picker.
  String? picked;

  /// When set, [checkRoot] returns it instead of looking at the directory.
  RootAccess? access;

  /// Every [list] call, for checking each pack folder is listed once.
  final listed = <String>[];

  DirectoryPackStorage({this.picked});

  @override
  Future<String?> pickFolder({String? initial}) async => picked;

  @override
  Future<RootAccess> checkRoot(String root) async =>
      access ?? (Directory(root).existsSync() ? RootAccess.ok : RootAccess.missing);

  @override
  Future<List<StorageEntry>> list(String dirUri) async {
    listed.add(dirUri);
    return [
      for (final e in Directory(dirUri).listSync())
        StorageEntry(name: p.basename(e.path), uri: e.path, isDir: e is Directory),
    ];
  }

  @override
  Future<String> readText(String fileUri) => File(fileUri).readAsString();

  @override
  String describe(String root) => root;
}

/// A temporary copy of `test/fixtures/packs`, safe to change. Delete it in tearDown.
Directory copyFixturePacks() {
  final dir = Directory.systemTemp.createTempSync('ohrwurm_packs_');
  for (final pack in Directory('test/fixtures/packs').listSync().whereType<Directory>()) {
    final target = Directory(p.join(dir.path, p.basename(pack.path)))..createSync();
    for (final f in pack.listSync().whereType<File>()) {
      f.copySync(p.join(target.path, p.basename(f.path)));
    }
  }
  return dir;
}

String get schemaJson => File('schema/manifest.v2.schema.json').readAsStringSync();
