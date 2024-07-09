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

import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// Available operators to use to check for equality/inequality.
/// Note that there are no greater than operators, since the
/// [EqualityQueryWidget] is designed such that it doesn't need them.
enum EqualityOperator {
  eq("=", "eq", "eq"),
  neq("\u2260", "neq", "neq"),
  lt("<", "gt", "lt"),
  lte("\u2264", "gte", "lte"),
  blank(" ", " ", " "),
  startsWith("starts with", null, "starts with"),
  endsWith("ends with", null, "ends with"),
  contains("contains", null, "contains");

  const EqualityOperator(this.symbol, this.queryLeft, this.queryRight);

  /// The symbol representing the operator
  final String symbol;

  /// The name of the operator in a query.
  /// Note that if this operator is to the left of the
  /// field name, for numbers the operator will flip,
  /// 5 < x -> x > 5.
  final String? queryLeft;

  /// The name of the operator to the right of the field
  /// name in a query.
  final String queryRight;

  String getName(EqualityOperator op) {
    List<String> parts = op.toString().split('.');
    return parts[1];
  }

  static EqualityOperator? fromString(String symbol) {
    for (var op in EqualityOperator.values) {
      if (op.symbol == symbol) {
        return op;
      }
    }
    return null; // or throw an exception if a symbol is not found
  }
}

/// A boolean operator in a query to combine two or more query terms.
enum QueryOperator {
  and("\u2227", "AND"),
  or("\u2228", "OR"),
  xor("\u2295", "XOR"),
  not("\u00AC", "NOT"),
  blank(" ", "");

  const QueryOperator(this.symbol, this.name);

  /// A symbol that represents the operator
  final String symbol;

  /// The name of the operator
  final String name;

  static QueryOperator? fromString(String symbol) {
    for (var op in QueryOperator.values) {
      if (op.symbol == symbol) {
        return op;
      }
    }
    return null; // or throw an exception if a symbol is not found
  }
}

/// An error in a query.
class QueryError implements Exception {
  QueryError(this.message);

  /// Message to be displayed when this [Exception] is thrown.
  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

/// A query that can be used to filter data.
abstract class Query {
  UniqueId id;
  QueryOperation? parent;
  Query({required this.id, this.parent});

  Map<String, dynamic> toDict();

  factory Query.fromDict(Map<String, dynamic> dict) => throw UnimplementedError();

  Query operator &(Query other) => QueryOperation(
        id: UniqueId.next(),
        children: [this, other],
        operator: QueryOperator.and,
      );
}

/// A query that checks that values satisfy a left and/or right equality.
/// Examples: 3 < x, x < 8, 3 < x < 8.
class EqualityQuery extends Query {
  /// The left hand value to check against.
  dynamic leftValue;

  EqualityOperator? leftOperator;

  /// The [field] against which the condition will be applied.
  final SchemaField field;

  /// The equality/inequality operator.
  EqualityOperator? rightOperator;

  /// The right hand value to check against.
  dynamic rightValue;

  EqualityQuery({
    required super.id,
    super.parent,
    this.leftValue,
    this.leftOperator,
    required this.field,
    this.rightOperator,
    this.rightValue,
  }) : assert((leftValue == null && leftOperator == null || leftValue != null && leftOperator != null) &&
            (rightValue == null && rightOperator == null || rightValue != null && rightOperator != null));

  @override
  String toString() {
    StringBuffer result = StringBuffer();

    if (leftValue != null) {
      result.write("$leftValue ${leftOperator!.symbol} ");
    }

    result.write(field.name);

    if (rightValue != null) {
      result.write(" ${rightOperator!.symbol} $rightValue");
    }

    return result.toString();
  }

  @override
  Map<String, dynamic> toDict() {
    Map<String, dynamic>? leftQuery;
    Map<String, dynamic>? rightQuery;
    if (leftValue != null) {
      leftQuery = {
        "name": "EqualityQuery",
        "content": {
          "column": "${field.schema.name}.${field.name}",
          "operator": leftOperator!.queryLeft,
          "value": "$leftValue",
        }
      };
    }
    if (rightValue != null) {
      rightQuery = {
        "name": "EqualityQuery",
        "content": {
          "column": "${field.schema.name}.${field.name}",
          "operator": rightOperator!.queryRight,
          "value": "$rightValue",
        }
      };
    }
    if (leftQuery != null && rightQuery != null) {
      return {
        "name": "ParentQuery",
        "content": {
          "operator": "AND",
          "children": [leftQuery, rightQuery],
        }
      };
    } else if (leftQuery != null) {
      return leftQuery;
    } else if (rightQuery != null) {
      return rightQuery;
    } else {
      throw QueryError("EqualityQuery has no left or right value!");
    }
  }
}

/// A query that combines two or more queries with a boolean operator.
class QueryOperation extends Query {
  /// The queries to combine.
  final List<Query> _children;

  /// The operator to combine the queries.
  QueryOperator operator;

  QueryOperation({
    required super.id,
    super.parent,
    required List<Query> children,
    required this.operator,
  }) : _children = children {
    for (Query child in children) {
      child.parent = this;
    }
  }

  /// The children of this query.
  List<Query> get children => [..._children];

  /// Remove a child from this query.
  void removeChild(Query child) {
    _children.remove(child);
    child.parent = null;
  }

  /// Add a child to this query.
  void addChild(Query child) {
    _children.add(child);
    child.parent = this;
  }

  /// Add multiple children to this query.
  void addAllChildren(List<Query> children) {
    _children.addAll(children);
    for (Query child in children) {
      child.parent = this;
    }
  }

  @override
  String toString() => "(${children.join(' ${operator.symbol} ')})";

  @override
  Map<String, dynamic> toDict() {
    Map<String, dynamic> result = {
      "name": "ParentQuery",
      "id": id.toSerializableString(),
      "content": {
        "operator": operator.name,
        "children": children.map((e) => e.toDict()).toList(),
      }
    };
    return result;
  }

  /// Create a [QueryOperation] from a dictionary.
  static QueryOperation fromDict(Map<String, dynamic> dict) {
    List<Query> children = [];
    for (Map<String, dynamic> child in dict["content"]["children"]) {
      children.add(Query.fromDict(child));
    }
    return QueryOperation(
      id: UniqueId.fromString(dict["id"]),
      children: children,
      operator: QueryOperator.values.firstWhere((element) => element.name == dict["content"]["operator"]),
    );
  }
}

/// A query that combines two or more queries with a boolean operator.
class QueryExpression {
  /// The queries in the expression.
  final List<Query> _queries;

  QueryExpression({
    required List<Query> queries,
  }) : _queries = queries;

  /// The queries in the expression.
  List<Query> get queries => [..._queries];

  /// Remove a query from the expression.
  void removeQuery(Query query) {
    _queries.remove(query);
  }

  /// Add a query to the expression.
  void addQuery(Query query) {
    _queries.add(query);
    query.parent = null;
  }

  /// Add multiple queries to the expression.
  void addAllQueries(List<Query> queries) {
    _queries.addAll(queries);
    for (Query query in queries) {
      query.parent = null;
    }
  }
}
