/// This file is part of the rubintv_visualization package.
///
/// Developed for the LSST Data Management System.
/// This product includes software developed by the LSST Project
/// (https://www.lsst.org).
/// See the COPYRIGHT file at the top-level directory of this distribution
/// for details of code ownership.
///
/// This program is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.
///
/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with this program.  If not, see <https://www.gnu.org/licenses/>.

/// The ID for the next [UniqueId].
BigInt _nextId = BigInt.zero;

/// A unique identifier for each [IpiObjectInstance].
/// A new instance can only be created using the static [next] method,
/// which automatically increments the counter.
class UniqueId {
  /// The unique ID.
  final BigInt id;

  UniqueId._(this.id);

  /// Create a new ID and increment the [_nextId] counter.
  static UniqueId next() {
    BigInt myId = _nextId;
    _nextId += BigInt.one;
    return UniqueId._(myId);
  }

  /// Create a new child id from an existing code
  static UniqueId from({
    required BigInt id,
  }) =>
      UniqueId._(id);

  static UniqueId fromString(String id) => UniqueId._(BigInt.parse(id));

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
  static get dummy => UniqueId._(BigInt.from(-1));

  @override
  String toString() => "Id<$id>";

  /// Convert the ID to a string
  String toSerializableString() => id.toString();
}
