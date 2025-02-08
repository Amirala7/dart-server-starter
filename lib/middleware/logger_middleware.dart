import 'dart:io';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:customlabs_backend/services/log_rotation_service.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  late File _logFile;
  bool _initialized = false;
  final _rotationService = LogRotationService();
  IOSink? _logSink;

  factory LoggerService() {
    return _instance;
  }

  LoggerService._internal();

  Future<void> setupLogger() async {
    if (_initialized) return;

    
    // Create logs directory if it doesn't exist
    final logsDir = Directory('logs');
    if (!await logsDir.exists()) {
      await logsDir.create();
    }

    // Create or open log file with current date
    final today = DateTime.now().toIso8601String().split('T')[0];
    _logFile = File(path.join('logs', 'server_$today.log'));
    _rotationService.rotateIfNeeded(_logFile.path);
    
    // Set up logging
    Logger.root.level = Level.INFO;
    Logger.root.onRecord.listen((record) {
      final logMessage = _formatLogMessage(record);
      
      // Console output with color
      _printToConsole(record);
      
      // File output
      try {
        _logFile.writeAsStringSync(
          '$logMessage\n',
          mode: FileMode.append,
          flush: true
        );
      } catch (e) {
        stderr.writeln('Failed to write to log file: $e');
      }
    });

    _initialized = true;
  }

  Future<void> close() async {
    if (_logSink != null) {
      await _logSink!.flush();
      await _logSink!.close();
      _logSink = null;
    }
  }

  String _formatLogMessage(LogRecord record) {
    final timestamp = _formatTimestamp(record.time);
    final level = record.level.name.padRight(7);
    final loggerName = record.loggerName.padRight(15);
    final message = record.message.trim();
    final error = record.error != null ? '\n  ├─ Error: ${record.error}' : '';
    final stackTrace = record.stackTrace != null ? '\n  └─ ${record.stackTrace.toString().replaceAll('\n', '\n     ')}' : '';

    return '$timestamp [$level] $loggerName: $message$error$stackTrace';
  }

  String _formatTimestamp(DateTime time) {
    return '${time.year}-'
           '${time.month.toString().padLeft(2, '0')}-'
           '${time.day.toString().padLeft(2, '0')} '
           '${time.hour.toString().padLeft(2, '0')}:'
           '${time.minute.toString().padLeft(2, '0')}:'
           '${time.second.toString().padLeft(2, '0')}.'
           '${time.millisecond.toString().padLeft(3, '0')}';
  }

  void _printToConsole(LogRecord record) {
    // ANSI color codes
    const reset = '\x1B[0m';
    const gray = '\x1B[90m';
    final levelColor = _getLevelColor(record.level);
    
    // Format components separately
    final timestamp = _formatTimestamp(record.time);
    final level = record.level.name.padRight(7);
    final loggerName = record.loggerName.padRight(15);
    final message = record.message;
    final error = record.error != null ? '\n  ├─ Error: ${record.error}' : '';
    final stackTrace = record.stackTrace != null ? '\n  └─ ${record.stackTrace.toString().replaceAll('\n', '\n     ')}' : '';

    // Combine with colors
    final coloredLog = '$gray$timestamp$reset '
                      '$levelColor[$level]$reset '
                      '$levelColor$loggerName:$reset '
                      '$message$error$stackTrace';
    
    stdout.writeln(coloredLog);
  }

  String _getLevelColor(Level level) {
    switch (level) {
      case Level.SEVERE:
        return '\x1B[31m'; // Red
      case Level.WARNING:
        return '\x1B[33m'; // Yellow
      case Level.INFO:
        return '\x1B[36m'; // Cyan
      case Level.FINE:
      case Level.FINER:
      case Level.FINEST:
        return '\x1B[32m'; // Green
      default:
        return '\x1B[37m'; // White
    }
  }
}

Logger getLogger(String name) {
  return Logger(name);
} 