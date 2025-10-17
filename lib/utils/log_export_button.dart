import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:rubintv_visualization/utils/browser_logger.dart';
import 'package:web/web.dart' as web;

/// A widget that shows a button to export logs
class LogExportButton extends StatelessWidget {
  const LogExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.download, color: Colors.purple),
      onPressed: _exportLogs,
    );
  }

  /// Export logs from local storage to a downloadable file
  void _exportLogs() {
    try {
      // Get logs from localStorage
      const key = 'rubintv_visualization_log';
      final logs = web.window.localStorage[key] ?? 'No logs found';

      // Create a data URL instead of using Blob (simpler approach)
      final encodedLogs = Uri.encodeComponent(logs);
      final url = 'data:text/plain;charset=utf-8,$encodedLogs';

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final filename = 'rubintv_logs_$timestamp.txt';

      // Create an anchor element and trigger download
      final a = web.document.createElement('a') as web.HTMLAnchorElement;
      a.href = url;
      a.download = filename;
      a.style.display = 'none';
      web.document.body!.appendChild(a);
      a.click();

      // Clean up
      web.document.body!.removeChild(a);
      web.URL.revokeObjectURL(url);

      // Also print to console for convenience
      printLogsToConsole();
    } catch (e) {
      developer.log('Error exporting logs: $e', name: 'LogExportButton', error: e);
    }
  }
}
