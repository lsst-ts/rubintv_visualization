# RubinTV Visualization Logging

This document describes how the logging system works in RubinTV Visualization.

## Overview

The application uses a dual logging system:
1. Standard Flutter console logging via `dart:developer`
2. Browser-based logging using Local Storage for persistent records and debugging

## Browser-based Logging

For web applications, logs are stored in the browser's Local Storage and can be exported as follows:

1. Use the Log Export button in the UI to download the logs as a text file
2. Access logs via the browser console by running: `printLogsToConsole()`

The log files use a timestamp-based naming convention and are automatically rotated when they reach 5MB in size.

## Log Levels

The logging system uses the following log levels:
- **Level 0**: INFO - General information
- **Level 1**: DEBUG - Debugging information
- **Level 2**: WARNING - Warnings
- **Level 3**: ERROR - Errors
- **Level 4**: CRITICAL - Critical errors

## Using the Logger

To log messages in the codebase:

```dart
import 'package:rubintv_visualization/utils/browser_logger.dart';

// Simple log
logWithFile('Some message', name: 'component.name');

// Log with error and stack trace
logWithFile(
  'Error occurred',
  name: 'component.name',
  level: 3, // ERROR level
  error: exception,
  stackTrace: stackTrace,
);

// Print all stored logs to console (useful for debugging)
printLogsToConsole();
```

## Log Format

Each log entry includes:
- Timestamp
- Log level
- Component name
- Message
- Optional error information and stack traces

## Log Levels

The logging system uses the following log levels:
- **Level 0**: INFO - General information
- **Level 1**: DEBUG - Debugging information
- **Level 2**: WARNING - Warnings
- **Level 3**: ERROR - Errors
- **Level 4**: CRITICAL - Critical errors

## Adding the Log Export Button

To add the log export button to your UI:

```dart
import 'package:rubintv_visualization/utils/log_export_button.dart';

// Then in your widget tree:
AppBar(
  actions: [
    const LogExportButton(), // Add this to your app bar or toolbar
  ],
)
```
```
