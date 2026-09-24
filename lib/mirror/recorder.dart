import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Records the user repeating a sentence (APP_SPEC 12). An interface so Mirror can be tested
/// without a microphone.
abstract class Recorder {
  /// Starts recording into a new temporary file.
  Future<void> start();

  /// Stops and returns the recording's file path, or null if nothing was recorded.
  Future<String?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();

  /// Deletes a recording made by this recorder. Recordings are temporary (APP_SPEC 12).
  Future<void> delete(String path);

  Future<void> dispose();
}

enum MicAccess { granted, denied, deniedForever }

/// The microphone permission, asked for on the first Record, not at launch (APP_SPEC 12).
abstract class MicPermission {
  Future<MicAccess> request();

  /// The phone's settings page for this app, where a refused permission can be allowed.
  Future<void> openSettings();
}

class PlatformMicPermission implements MicPermission {
  @override
  Future<MicAccess> request() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicAccess.granted;
    return status.isPermanentlyDenied ? MicAccess.deniedForever : MicAccess.denied;
  }

  @override
  Future<void> openSettings() => openAppSettings();
}

/// [Recorder] on the `record` package: AAC in `.m4a`, in the app's temporary directory. Nothing
/// leaves the phone.
class PlatformRecorder implements Recorder {
  final _recorder = AudioRecorder();
  int _count = 0;

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'mirror_${DateTime.now().millisecondsSinceEpoch}_${_count++}.m4a',
    );
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
      path: path,
    );
  }

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> delete(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
