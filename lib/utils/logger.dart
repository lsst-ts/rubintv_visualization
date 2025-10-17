import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:flutter/foundation.dart';

/// A logger that captures developer.log messages and writes them to a file
/// in addition to the debug console.
class FileLogger {
  /// The singleton instance of the file logger
  static FileLogger? _instance;

  /// The log file
  io.File? _logFile;

  /// Whether the logger is initialized
  bool _initialized = false;

  /// Maximum log file size in bytes (default: 5MB)
  final int maxLogSize;

  /// Log directory path
  String? _logDirectory;

  /// Log file path
  String get logFilePath => _logFile?.path ?? 'Not initialized';

  /// Private constructor
  FileLogger._({this.maxLogSize = 5 * 1024 * 1024});

  /// Get the singleton instance of the file logger
  static Future<FileLogger> getInstance({int maxLogSize = 5 * 1024 * 1024}) async {
    if (_instance == null) {
      _instance = FileLogger._(maxLogSize: maxLogSize);
      await _instance!._initialize();
    }
    return _instance!;
  }

  /// Initialize the file logger
  Future<void> _initialize() async {
    if (_initialized) return;

    try {
      if (kIsWeb) {
        // Web platform doesn't support file IO directly
        _initialized = true;
        developer.log('File logger running in web mode (file logging not available)', name: 'FileLogger');
        return;
      }

      // Get current working directory and print it to help debug
      String currentDir = io.Directory.current.path;
      developer.log('Current working directory: $currentDir', name: 'FileLogger');

      // Create logs relative to the current working directory
      // First try to create it in the project root
      String possibleProjectRoot = currentDir;

      // Try to locate the project root by looking for pubspec.yaml
      while (possibleProjectRoot.isNotEmpty && !await io.File('$possibleProjectRoot/pubspec.yaml').exists()) {
        final dir = io.Directory(possibleProjectRoot);
        final parent = dir.parent;
        if (parent.path == possibleProjectRoot) {
          break; // Reached root directory
        }
        possibleProjectRoot = parent.path;
      }

      // If we found a pubspec.yaml, use that directory, otherwise use current directory
      if (await io.File('$possibleProjectRoot/pubspec.yaml').exists()) {
        _logDirectory = '$possibleProjectRoot/logs';
        developer.log('Found project root, log directory set to: $_logDirectory', name: 'FileLogger');
      } else {
        _logDirectory = '$currentDir/logs';
        developer.log('Could not find project root, log directory set to: $_logDirectory',
            name: 'FileLogger');
      }

      // Create the logs directory if it doesn't exist
      final logDir = io.Directory(_logDirectory!);
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
        developer.log('Created log directory: ${logDir.path}', name: 'FileLogger');
      } else {
        developer.log('Log directory already exists: ${logDir.path}', name: 'FileLogger');
      }

      // Create or open the log file
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final logFilePath = '${logDir.path}/rubintv_visualization_$timestamp.log';
      developer.log('Creating log file at: $logFilePath', name: 'FileLogger');

      _logFile = io.File(logFilePath);

      try {
        // Write header to the log file
        await _logFile!.writeAsString('--- RubinTV Visualization Log Started at $timestamp ---\n',
            mode: io.FileMode.writeOnly);
        developer.log('Successfully created and wrote to log file', name: 'FileLogger');
      } catch (e) {
        developer.log('Error writing to log file: $e', name: 'FileLogger', error: e);
      }

      _initialized = true;

      developer.log('File logger initialized. Log file: ${_logFile!.path}', name: 'FileLogger');
      log('File logger initialized. Log file: ${_logFile!.path}', name: 'FileLogger', level: 1);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to initialize file logger: $e',
        name: 'FileLogger',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log a message to the file and debug console
  void log(
    String message, {
    DateTime? time,
    int? sequenceNumber,
    int level = 0,
    String name = '',
    Zone? zone,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Always log to developer console
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

    // Log to file if initialized and not on web
    _logToFile(
      message,
      time: time ?? DateTime.now(),
      level: level,
      name: name,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log a message to the file
  Future<void> _logToFile(
    String message, {
    required DateTime time,
    int level = 0,
    String name = '',
    Object? error,
    StackTrace? stackTrace,
  }) async {
    if (!_initialized || _logFile == null || kIsWeb) return;

    try {
      // Format the log message
      final timeString = time.toIso8601String();
      final levelString = _getLevelString(level);
      final buffer = StringBuffer();

      buffer.write('[$timeString][$levelString]');
      if (name.isNotEmpty) buffer.write('[$name]');
      buffer.write(' $message');

      if (error != null) {
        buffer.write('\nError: $error');
      }

      if (stackTrace != null) {
        buffer.write('\nStack trace:\n$stackTrace');
      }

      buffer.write('\n');

      // Write to log file
      await _logFile!.writeAsString(
        buffer.toString(),
        mode: io.FileMode.append,
        flush: true,
      );

      // Check file size and rotate if needed
      await _checkRotateLogFile();
    } catch (e) {
      // Don't try to log this error to the file to avoid infinite recursion
      developer.log(
        'Failed to write to log file: $e',
        name: 'FileLogger',
        error: e,
      );
    }
  }

  /// Convert the log level to a string
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

  /// Check if the log file needs to be rotated
  Future<void> _checkRotateLogFile() async {
    if (_logFile == null || !_initialized) return;

    try {
      final fileStats = await _logFile!.stat();

      if (fileStats.size > maxLogSize) {
        // Create a new log file with timestamp
        final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
        final newLogFile = io.File('$_logDirectory/rubintv_visualization_$timestamp.log');

        // Write header to the new log file
        await newLogFile.writeAsString('--- RubinTV Visualization Log Started at $timestamp ---\n',
            mode: io.FileMode.writeOnly);

        // Update log file reference
        _logFile = newLogFile;

        log('Log file rotated. New log file: ${newLogFile.path}', name: 'FileLogger', level: 1);
      }
    } catch (e) {
      developer.log(
        'Failed to check/rotate log file: $e',
        name: 'FileLogger',
        error: e,
      );
    }
  }
}

/// Global function to log with file output
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
  // Get logger instance
  final logger = await FileLogger.getInstance();

  // Log the message
  logger.log(
    message,
    time: time,
    sequenceNumber: sequenceNumber,
    level: level,
    name: name,
    zone: zone,
    error: error,
    stackTrace: stackTrace,
  );
}
