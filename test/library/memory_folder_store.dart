import 'package:ohrwurm/library/library_controller.dart';

/// A [RootFolderStore] in memory, in place of `shared_preferences`.
class MemoryFolderStore implements RootFolderStore {
  String? uri;

  MemoryFolderStore([this.uri]);

  @override
  Future<String?> load() async => uri;

  @override
  Future<void> save(String uri) async => this.uri = uri;
}

/// A [RejectionStore] in memory, in place of `shared_preferences`.
class MemoryRejectionStore implements RejectionStore {
  Set<String> keys = {};

  @override
  Future<Set<String>> load() async => {...keys};

  @override
  Future<void> save(Set<String> keys) async => this.keys = {...keys};
}
