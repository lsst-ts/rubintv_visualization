/// Cast a list of dynamic to a list of T.
/// This is useful when the type of the list is known at runtime,
/// but the list might be empty so that dart has difficulty casting it
/// to the appropriate type.
List<T> safeCastList<T>(List<dynamic> list) {
  if (list.isEmpty) return [];
  return list.cast<T>();
}
