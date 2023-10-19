import 'package:flutter/widgets.dart';

/// The ID for the next [UniqueId].
BigInt _nextId = BigInt.zero;

/// A unique identifier for each [IpiObjectInstance].
/// A new instance can only be created using the static [next] method,
/// which automatically increments the counter.
class UniqueId {
  final BigInt id;
  final GlobalKey key;

  UniqueId._(this.id, this.key);

  /// Create a new ID and increment the [_nextId] counter.
  static UniqueId next() {
    BigInt myId = _nextId;
    _nextId += BigInt.one;
    return UniqueId._(myId, GlobalKey());
  }

  /// Create a new child id from an existing code
  static UniqueId from({
    required BigInt id,
  }) =>
      UniqueId._(id, GlobalObjectKey(id));

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) => other is UniqueId && other.id == id;

  /// This should only be used when loading a persistable set of IDs,
  /// so that the nextId can be persisted as well
  static void setNextId(BigInt id) {
    _nextId = id;
  }

  /// Dummy id, used in place of a null value.
  static get dummy => UniqueId._(BigInt.from(-1), GlobalKey());

  @override
  String toString() => "Id<$id>";
}
