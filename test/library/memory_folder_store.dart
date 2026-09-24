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
