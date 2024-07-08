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

import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// An update to a query
class QueryUpdate {
  const QueryUpdate();
}

/// Replace a [Query] in a full query expression
class RemoveQuery extends QueryUpdate {
  /// The query to remove
  final Query query;

  /// Whether to keep or remove children of this [Query].
  final bool keepChildren;

  const RemoveQuery({
    required this.query,
    this.keepChildren = false,
  });
}

/// Add a new [EqualityQuery] to the expression.
class AddNewQuery extends QueryUpdate {
  /// The name of the column for the query.
  final SchemaField column;

  const AddNewQuery({required this.column});
}

/// Connect two queries using a boolean operation
class ConnectQueries extends QueryUpdate {
  /// The target [Query].
  final Query target;

  /// The [Query] that is being dragged.
  final Query query;

  /// The operator to use while connecting them.
  final QueryOperator operator;

  ConnectQueries({
    required this.target,
    required this.query,
    this.operator = QueryOperator.and,
  });
}

/// A callback function to update a query
typedef QueryUpdateCallback = void Function(QueryUpdate update);
