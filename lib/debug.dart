import 'dart:developer' as developer;

void debugStatement(Function function, String module) {
  try {
    function();
  } catch (e, stackTrace) {
    developer.log("Error: $e", name: module);
    developer.log(stackTrace.toString(), name: module);
  }
}
