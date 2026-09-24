/// The folder that holds the packs, as rescan sees it (APP_SPEC 5).
///
/// Like `ClipPlayer`, this is an interface so rescan can be tested on desktop against real
/// folders: `SafPackStorage` is the device implementation.
library;

/// Whether the saved root folder can be read (APP_SPEC 5.3).
enum RootAccess {
  ok,

  /// The root doesn't exist: moved, deleted, storage unmounted — or not visible yet shortly after
  /// boot (A0 finding 3).
  missing,

  /// The persisted permission is gone, or reading throws.
  denied,
}

/// A file or folder directly inside a folder.
class StorageEntry {
  final String name;
  final String uri;
  final bool isDir;

  const StorageEntry({required this.name, required this.uri, required this.isDir});
}

abstract class PackStorage {
  /// Asks the user for a folder. Returns the URI to save, or null if they cancelled.
  /// [initial] is a previously saved URI to open the picker at.
  Future<String?> pickFolder({String? initial});

  /// Checks the root folder itself. A folder that has moved lists as empty without an error, so a
  /// successful [list] proves nothing (A0 finding 2).
  Future<RootAccess> checkRoot(String root);

  /// The entries directly inside [dirUri], in one query (A0 finding 1).
  Future<List<StorageEntry>> list(String dirUri);

  /// The contents of the file at [fileUri], as UTF-8 text.
  Future<String> readText(String fileUri);

  /// A readable location for [root], for display.
  String describe(String root);
}
