import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// Available operators to use to check for equality/inequality.
/// Note that there are no greater than operators, since the
/// [EqualityQueryWidget] is designed such that it doesn't need them.
enum EqualityOperator {
  eq("="),
  neq("\u2260"),
  lt("<"),
  lte("\u2264"),
  blank(" "),
  startsWith("starts with"),
  endsWith("ends with"),
  contains("contains");

  const EqualityOperator(this.symbol);

  /// The symbol representing the operator
  final String symbol;
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
}

/// An error in a query.
class QueryError implements Exception {
  QueryError(this.message);

  /// Message to be displayed when this [Exception] is thrown.
  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

class Query {
  UniqueId id;
  QueryOperation? parent;
  Query({required this.id, this.parent});
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
  }) : assert((leftValue == null && leftOperator == null ||
                leftValue != null && leftOperator != null) &&
            (rightValue == null && rightOperator == null ||
                rightValue != null && rightOperator != null));

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
}

class QueryExpression {
  List<Query> _queries;
  DataCenter dataCenter;

  QueryExpression({
    required List<Query> queries,
    required this.dataCenter,
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
