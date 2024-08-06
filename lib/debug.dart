void debugStatement(Function function) {
  try {
    function();
  } catch (e, stackTrace) {
    print("Error: $e");
    print(stackTrace);
  }
}
