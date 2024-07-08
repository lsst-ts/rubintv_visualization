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

  /*static EqualityQuery fromDict(Map<String, dynamic> dict) {
    return EqualityQuery(
      id: UniqueId.fromString(dict["id"]),
      leftValue: Query.fromDict()
    );
  }*/
}

class QueryOperation extends Query {
  final List<Query> _children;
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

  List<Query> get children => [..._children];

  void removeChild(Query child) {
    _children.remove(child);
    child.parent = null;
  }

  void addChild(Query child) {
    _children.add(child);
    child.parent = this;
  }

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

class QueryExpression {
  List<Query> _queries;

  QueryExpression({
    required List<Query> queries,
  }) : _queries = queries;

  List<Query> get queries => [..._queries];

  void removeQuery(Query query) {
    _queries.remove(query);
  }

  void addQuery(Query query) {
    _queries.add(query);
    query.parent = null;
  }

  void addAllQueries(List<Query> queries) {
    _queries.addAll(queries);
    for (Query query in queries) {
      query.parent = null;
    }
  }
}
