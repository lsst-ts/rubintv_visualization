import 'dart:async';
import 'dart:developer' as developer;
import 'package:web/web.dart' as web;

// Simple function to create a debug file in the web browser's local storage
Future<void> logWithFile(
  String message, {
  DateTime? time,
  int? sequenceNumber,
  int level = 0,
  String name = '',
  Zone? zone,
  Object? error,
  StackTrace? stackTrace,
}) async {
  // Log to developer console
  developer.log(
    message,
    time: time,
    sequenceNumber: sequenceNumber,
    level: level,
    name: name,
    zone: zone,
    error: error,
    stackTrace: stackTrace,
  );

  try {
    // Format the log message for local storage
    final timestamp = DateTime.now().toIso8601String();
    final levelString = _getLevelString(level);
    final buffer = StringBuffer();

    buffer.write('[$timestamp][$levelString]');
    if (name.isNotEmpty) buffer.write('[$name]');
    buffer.write(' $message');

    if (error != null) {
      buffer.write('\nError: $error');
    }

    if (stackTrace != null) {
      buffer.write('\nStack trace:\n$stackTrace');
    }

    // Append to the log in local storage
    final key = 'rubintv_visualization_log';
    String existingLog = web.window.localStorage[key] ?? '';

    // Keep logs under 1MB by trimming oldest entries if needed
    if (existingLog.length > 1000000) {
      final lines = existingLog.split('\n');
      existingLog = lines.skip(lines.length ~/ 2).join('\n');
    }

    web.window.localStorage[key] = existingLog + buffer.toString() + '\n';
  } catch (e) {
    developer.log(
      'Failed to write to local storage log: $e',
      name: 'FileLogger',
      error: e,
    );
  }
}

// Helper function to convert log level to string
String _getLevelString(int level) {
  switch (level) {
    case 0:
      return 'INFO';
    case 1:
      return 'DEBUG';
    case 2:
      return 'WARNING';
    case 3:
      return 'ERROR';
    case 4:
      return 'CRITICAL';
    default:
      return 'LEVEL$level';
  }
}

// Helper to expose logs through the console
void printLogsToConsole() {
  try {
    final key = 'rubintv_visualization_log';
    final logs = web.window.localStorage[key] ?? 'No logs found';
    developer.log('=== BEGIN LOGS ===');
    developer.log(logs);
    developer.log('=== END LOGS ===');
  } catch (e) {
    developer.log('Error reading logs: $e', error: e);
  }
}
