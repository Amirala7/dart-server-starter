import 'dart:io';
import 'package:path/path.dart' as path;

class LogRotationService {
  static const int MAX_LOG_SIZE_MB = 10;
  static const int MAX_LOG_FILES = 5;

  Future<void> rotateIfNeeded(String logPath) async {
    final file = File(logPath);
    if (!await file.exists()) return;

    final size = await file.length();
    if (size > MAX_LOG_SIZE_MB * 1024 * 1024) {
      await _rotateLog(file);
    }
  }

  Future<void> _rotateLog(File logFile) async {
    final dir = logFile.parent;
    final basename = path.basenameWithoutExtension(logFile.path);
    final extension = path.extension(logFile.path);

    // Rotate existing backup files
    for (var i = MAX_LOG_FILES - 1; i >= 1; i--) {
      final file = File('${dir.path}/$basename.$i$extension');
      if (await file.exists()) {
        if (i == MAX_LOG_FILES - 1) {
          await file.delete();
        } else {
          await file.rename('${dir.path}/$basename.${i + 1}$extension');
        }
      }
    }

    // Rename current log file
    await logFile.rename('${dir.path}/$basename.1$extension');
  }
} 