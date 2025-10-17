import 'package:rubintv_visualization/utils/browser_logger.dart';

/// Debug a statement and log any errors.
/// This is useful when the VS code debugger does not show the full error.
void debugStatement(Function function, [String? module]) {
  try {
    function();
  } catch (e, stackTrace) {
    // Log to both console and file
    logWithFile(
      "Error: $e",
      name: module ?? "debugStatement",
      level: 3, // ERROR level
      error: e,
      stackTrace: stackTrace,
    );
  }
}

/// Debug an asynchronous statement and log any errors.
Future<void> debugStatementAsynch(Function function, [String? module]) async {
  try {
    await function();
  } catch (e, stackTrace) {
    // Log to both console and file
    await logWithFile(
      "Error: $e",
      name: module ?? "debugStatementAsynch",
      level: 3, // ERROR level
      error: e,
      stackTrace: stackTrace,
    );
  }
}
