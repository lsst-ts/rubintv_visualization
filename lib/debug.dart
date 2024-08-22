import 'dart:developer' as developer;

/// Debug a statement and log any errors.
/// This is useful when the VS code debugger does not show the full error.
void debugStatement(Function function, [String? module]) {
  try {
    function();
  } catch (e, stackTrace) {
    developer.log("Error: $e", name: module ?? "debugStatement");
    developer.log(stackTrace.toString(), name: module ?? "debugStatement");
  }
}

/// Debug an asynchronous statement and log any errors.
Future<void> debugStatementAsynch(Function function, [String? module]) async {
  try {
    await function();
  } catch (e, stackTrace) {
    developer.log("Error: $e", name: module ?? "debugStatementAsynch");
    developer.log(stackTrace.toString(), name: module ?? "debugStatementAsynch");
  }
}
