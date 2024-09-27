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

  static EqualityOperator? fromSymbol(String symbol) {
    for (var op in EqualityOperator.values) {
      if (op.symbol == symbol) {
        return op;
      }
    }
    return null; // or throw an exception if a symbol is not found
  }

  static EqualityOperator? fromString(String name) {
    for (String op in EqualityOperator.values.map((e) => e.name)) {
      if (op == name) {
        return EqualityOperator.values.firstWhere((element) => element.name == name);
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

  static QueryOperator? fromSymbol(String symbol) {
    for (var op in QueryOperator.values) {
      if (op.symbol == symbol) {
        return op;
      }
    }
    return null; // or throw an exception if a symbol is not found
  }

  static QueryOperator? fromString(String name) {
    for (String op in QueryOperator.values.map((e) => e.name)) {
      if (op == name) {
        return QueryOperator.values.firstWhere((element) => element.name == name);
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
  final UniqueId id;
  const Query({required this.id});

  Map<String, dynamic> toJson(QueryExpression expression);

  factory Query.fromJson(Map<String, dynamic> json) {
    if (json['type'] == 'EqualityQuery') {
      return EqualityQuery.fromJson(json);
    } else if (json['type'] == 'ParentQuery') {
      return ParentQuery.fromJson(json);
    }
    throw QueryError('Unknown query type: ${json['type']}');
  }
}

/// A query that checks that values satisfy a left and/or right equality.
/// Examples: 3 < x, x < 8, 3 < x < 8.
class EqualityQuery extends Query {
  /// The left hand value to check against.
  final dynamic leftValue;

  final EqualityOperator? leftOperator;

  /// The [field] against which the condition will be applied.
  final SchemaField field;

  /// The equality/inequality operator.
  final EqualityOperator? rightOperator;

  /// The right hand value to check against.
  final dynamic rightValue;

  const EqualityQuery({
    required super.id,
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

  /// Convert the query to a JSON formatted string.
  @override
  Map<String, dynamic> toJson(QueryExpression expression) {
    Map<String, dynamic> result = {
      'type': 'EqualityQuery',
      'id': id.toSerializableString(),
      'field': field.toJson(),
    };
    if (leftOperator != null) {
      result['leftOperator'] = leftOperator!.name;
      result['leftValue'] = leftValue;
    }
    if (rightOperator != null) {
      result['rightOperator'] = rightOperator!.name;
      result['rightValue'] = rightValue;
    }
    return result;
  }

  /// Create an [EqualityQuery] from a dictionary.
  static EqualityQuery fromJson(Map<String, dynamic> json) {
    return EqualityQuery(
      id: UniqueId.fromString(json['id']),
      field: SchemaField.fromJson(json['field']),
      leftOperator: json['leftOperator'] != null
          ? EqualityOperator.values.firstWhere((e) => e.name == json['leftOperator'])
          : null,
      leftValue: json['leftValue'],
      rightOperator: json['rightOperator'] != null
          ? EqualityOperator.values.firstWhere((e) => e.name == json['rightOperator'])
          : null,
      rightValue: json['rightValue'],
    );
  }

  /// Create a copy of the query with filed updated.
  EqualityQuery copyWith({
    SchemaField? field,
  }) {
    return EqualityQuery(
      id: id,
      leftValue: leftValue,
      leftOperator: leftOperator,
      field: field ?? this.field,
      rightOperator: rightOperator,
      rightValue: rightValue,
    );
  }

  /// Create a copy of the query with the left value and operator updated.
  EqualityQuery updateLeft(EqualityOperator operator, dynamic value) => EqualityQuery(
        id: id,
        leftValue: value,
        leftOperator: operator,
        field: field,
        rightOperator: rightOperator,
        rightValue: rightValue,
      );

  /// Create a copy of the query with the right value and operator updated.
  EqualityQuery updateRight(EqualityOperator operator, dynamic value) => EqualityQuery(
        id: id,
        leftValue: leftValue,
        leftOperator: leftOperator,
        field: field,
        rightOperator: operator,
        rightValue: value,
      );
}

/// A query that combines two or more queries with a boolean operator.
class ParentQuery extends Query {
  /// The operator to combine the queries.
  QueryOperator operator;

  ParentQuery({
    required super.id,
    required this.operator,
  });

  @override
  String toString() => "ParentQuery<${operator.symbol}>";

  @override
  Map<String, dynamic> toJson(QueryExpression expression) {
    List<Query> children = expression!.children[id]!.map((childId) => expression.nodes[childId]!).toList();
    return {
      'type': 'ParentQuery',
      'id': id.toSerializableString(),
      'operator': operator.name,
      'children': children.map((e) => e.toJson(expression)).toList(),
    };
  }

  /// Create a [ParentQuery] from a dictionary.
  static ParentQuery fromJson(Map<String, dynamic> json) {
    return ParentQuery(
      id: UniqueId.fromString(json["id"]),
      operator: QueryOperator.values.firstWhere((element) => element.name == json["content"]["operator"]),
    );
  }

  ParentQuery copyWith({
    QueryOperator? operator,
  }) =>
      ParentQuery(
        id: id,
        operator: operator ?? this.operator,
      );
}

/// A query expression that represents a tree of queries.
/// The tree is represented by a map of nodes, a set of roots,
/// a map of children, and a map of parents.
class QueryExpression {
  /// The nodes in the query expression.
  final Map<UniqueId, Query> _nodes;

  /// The root nodes in the query expression.
  /// Before a query can be saved there must be one, and only one, root.
  final Set<UniqueId> _roots;

  /// The children of each node in the query expression.
  final Map<UniqueId, List<UniqueId>> _children;

  /// The parent of each node in the query expression.
  final Map<UniqueId, UniqueId> _parents;

  /// Private constructor to create a query expression
  /// with the given nodes, roots, children, and parents.
  const QueryExpression._internal(this._nodes, this._roots, this._children, this._parents);

  /// Create an empty query expression.
  factory QueryExpression.empty() => const QueryExpression._internal({}, {}, {}, {});

  /// Get the map of queryID: qurery for all nodes in the expression.
  Map<UniqueId, Query> get nodes => Map.unmodifiable(_nodes);

  /// Get the set of root nodes in the expression.
  Set<UniqueId> get roots => Set.unmodifiable(_roots);

  /// Get the map of queryID: children for all nodes in the expression.
  Map<UniqueId, List<UniqueId>> get children => Map.unmodifiable(_children);

  /// Get the map of queryID: parent for all nodes in the expression.
  Map<UniqueId, UniqueId> get parents => Map.unmodifiable(_parents);

  /// Add a new node to the expression.
  QueryExpression addNode(Query node, {UniqueId? parentId}) {
    final newNodes = {..._nodes, node.id: node};
    final newRoots = {..._roots};
    final newChildren = {..._children};
    final newParents = {..._parents};

    if (parentId != null) {
      if (newNodes[parentId] is! ParentQuery) {
        throw StateError('Parent must be a ParentQuery, got ${newNodes[parentId]}');
      }
      newChildren.update(parentId, (list) => list + [node.id], ifAbsent: () => [node.id]);
      newParents[node.id] = parentId;
      newRoots.remove(node.id);
    } else {
      newRoots.add(node.id);
    }

    return QueryExpression._internal(newNodes, newRoots, newChildren, newParents);
  }

  /// Update a node in the expression.
  QueryExpression updateNode(Query node) {
    final newNodes = {..._nodes, node.id: node};
    return QueryExpression._internal(newNodes, _roots, _children, _parents);
  }

  /// Remove a node from the expression.
  QueryExpression removeNode(UniqueId nodeId) {
    final newNodes = {..._nodes};
    final newRoots = {..._roots};
    final newChildren = {..._children};
    final newParents = {..._parents};

    // Reeursively remove the node and all its children
    void removeRecursively(UniqueId id) {
      newNodes.remove(id);
      newRoots.remove(id);
      newParents.remove(id);
      final childrenToRemove = newChildren.remove(id) ?? [];
      for (final childId in childrenToRemove) {
        removeRecursively(childId);
      }
    }

    removeRecursively(nodeId);

    // Update parent
    _removeFromParent(newNodes, newChildren, newParents, newRoots, nodeId);

    return QueryExpression._internal(newNodes, newRoots, newChildren, newParents);
  }

  /// Remove a node from its parent.
  void _removeFromParent(
    Map<UniqueId, Query> newNodes,
    Map<UniqueId, List<UniqueId>> newChildren,
    Map<UniqueId, UniqueId> newParents,
    Set<UniqueId> newRoots,
    UniqueId nodeId,
  ) {
    final parentId = newParents[nodeId];
    if (parentId != null) {
      newChildren[parentId] = newChildren[parentId]!.where((id) => id != nodeId).toList();
      if (newChildren[parentId]!.isEmpty) {
        // The parent is now empty, so remove it
        newChildren.remove(parentId);
        newParents.remove(parentId);
        newRoots.remove(parentId);
        newNodes.remove(parentId);
      } else if (newChildren[parentId]!.length == 1) {
        // The parent only has a single child, so replace the parent with the child
        Query child = newNodes[newChildren[parentId]!.first]!;
        if (newParents[parentId] != null) {
          UniqueId grandParentId = newParents[parentId]!;
          newParents[child.id] = grandParentId;
          // This should never happend, but just in case
          if (newChildren[grandParentId]!.contains(child.id)) {
            newChildren[grandParentId]!.remove(child.id);
            assert(true, "Child already exists in grandparent, this should never happen");
          }
          newChildren[grandParentId]!.add(child.id);
        } else {
          // The parent was in the roots, so add the child to the roots
          newRoots.add(child.id);
        }
        // Remove the parent
        newChildren.remove(parentId);
        newParents.remove(parentId);
        newRoots.remove(parentId);
        newNodes.remove(parentId);
      }
    }
  }

  /// Reparent a node in the expression.
  QueryExpression reparentNode(UniqueId nodeId, UniqueId? newParentId) {
    final newNodes = {..._nodes};
    final newRoots = {..._roots};
    final newChildren = {..._children};
    final newParents = {..._parents};

    // Remove from old parent
    final oldParentId = newParents[nodeId];
    if (oldParentId != null) {
      _removeFromParent(newNodes, newChildren, newParents, newRoots, nodeId);
    } else {
      newRoots.remove(nodeId);
    }

    // Add to new parent
    if (newParentId != null) {
      if (newNodes[newParentId] is! ParentQuery) {
        throw StateError('New parent must be a ParentQuery, got ${newNodes[newParentId]}');
      }
      newChildren.update(newParentId, (list) => [...list, nodeId], ifAbsent: () => [nodeId]);
      newParents[nodeId] = newParentId;
      newRoots.remove(nodeId);
    } else {
      newRoots.add(nodeId);
    }

    return QueryExpression._internal(newNodes, newRoots, newChildren, newParents);
  }

  /// Connect two queries with a binary operator.
  QueryExpression connectQueries(UniqueId targetId, UniqueId queryId, QueryOperator operator) {
    final newNodes = {..._nodes};
    final newRoots = {..._roots};
    final newChildren = {..._children};
    final newParents = {..._parents};

    // Create a new parent to combine both queries
    ParentQuery newParent = ParentQuery(id: UniqueId.next(), operator: operator);
    newNodes[newParent.id] = newParent;
    newParents[targetId] = newParent.id;
    newParents[queryId] = newParent.id;
    // Update the children of the new parent
    newChildren[newParent.id] = [targetId, queryId];

    // If either of the queries are roots, the new parent should be a root
    if (newRoots.contains(targetId) || newRoots.contains(queryId)) {
      newRoots.add(newParent.id);
      newRoots.remove(targetId);
      newRoots.remove(queryId);
    }

    return QueryExpression._internal(newNodes, newRoots, newChildren, newParents);
  }

  /// Check to see if the expression is valid.
  bool isValid() {
    Set<UniqueId> visited = {};
    bool hasCycle = false;

    void dfs(UniqueId nodeId, Set<UniqueId> path) {
      if (path.contains(nodeId)) {
        hasCycle = true;
        return;
      }
      if (visited.contains(nodeId)) return;
      visited.add(nodeId);
      path.add(nodeId);

      final childrenIds = _children[nodeId] ?? [];
      for (final childId in childrenIds) {
        if (!_nodes.containsKey(childId)) {
          throw StateError('Referenced node does not exist: $childId');
        }
        dfs(childId, path);
      }
      path.remove(nodeId);
    }

    for (final rootId in _roots) {
      dfs(rootId, {});
    }

    return !hasCycle && visited.length == _nodes.length;
  }

  /// Convert the expression to a JSON formatted string.
  Map<String, dynamic> toJson() {
    return {
      'nodes': _nodes.map((id, node) => MapEntry(id.toSerializableString(), node.toJson(this))),
      'roots': _roots.map((id) => id.toSerializableString()).toList(),
      'children': _children.map((id, children) => MapEntry(
          id.toSerializableString(), children.map((childId) => childId.toSerializableString()).toList())),
      'parents': _parents
          .map((id, parentId) => MapEntry(id.toSerializableString(), parentId.toSerializableString())),
    };
  }

  /// Create a [QueryExpression] from a dictionary.
  factory QueryExpression.fromJson(Map<String, dynamic> json) {
    final nodes = (json['nodes'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(UniqueId.fromString(key), Query.fromJson(value)),
    );
    final roots = (json['roots'] as List).map((id) => UniqueId.fromString(id as String)).toSet();
    final children = (json['children'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        UniqueId.fromString(key),
        (value as List).map((id) => UniqueId.fromString(id as String)).toList(),
      ),
    );
    final parents = (json['parents'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        UniqueId.fromString(key),
        UniqueId.fromString(value as String),
      ),
    );
    return QueryExpression._internal(nodes, roots, children, parents);
  }

  /// Convert the query expression to a format that the server can parse.
  Map<String, dynamic> toCommand() {
    return _nodes[roots.first]!.toJson(this);
  }
}
