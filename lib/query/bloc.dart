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

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/primitives.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// An event for a [QueryBloc].
abstract class QueryEvent {}

/// An event to add a query to the expression.
class AddQuery extends QueryEvent {
  /// The query to add.
  final Query query;

  /// The parent ID of the new query.
  final UniqueId? parentId;

  AddQuery(this.query, {this.parentId});
}

/// An event to remove a query from the expression.
class RemoveQuery extends QueryEvent {
  /// The ID of the query to remove.
  final UniqueId queryId;

  RemoveQuery(this.queryId);
}

/// An event to update an [EqualityQuery].
class UpdateEqualityQuery extends QueryEvent {
  /// The ID of the query after the update.
  final UniqueId id;

  /// The field after the update.
  final SchemaField field;

  /// The left operator after the update.
  final EqualityOperator? leftOperator;

  /// The left value after the update.
  final dynamic leftValue;

  /// The right operator after the update.
  final EqualityOperator? rightOperator;

  /// The right value after the update.
  final dynamic rightValue;

  UpdateEqualityQuery({
    required this.id,
    required this.field,
    this.leftOperator,
    this.leftValue,
    this.rightOperator,
    this.rightValue,
  });
}

/// An event to move a query from one parent to another (or the root, when null).
class ReparentQuery extends QueryEvent {
  /// The ID of the query to reparent.
  final UniqueId queryId;

  /// The ID of the new parent.
  final UniqueId? newParentId;

  ReparentQuery(this.queryId, this.newParentId);
}

/// An event to connect two queries with an operator.
class ConnectQueries extends QueryEvent {
  /// The ID of the target query.
  final UniqueId targetId;

  /// The ID of the query to connect.
  final UniqueId queryId;

  /// The operator to connect the queries with.
  final QueryOperator operator;

  ConnectQueries({
    required this.targetId,
    required this.queryId,
    required this.operator,
  });
}

/// An event to update the operator of a [ParentQuery].
class UpdateQueryOperator extends QueryEvent {
  /// The ID of the query to update.
  final UniqueId id;

  /// The new operator for the query.
  final QueryOperator newOperator;

  UpdateQueryOperator(this.id, this.newOperator);
}

/// An event to set the expression of the query.
class SetQueryExpression extends QueryEvent {
  /// The new expression.
  final QueryExpression expression;

  SetQueryExpression(this.expression);
}

/// The state of a [QueryBloc].
class QueryState {
  /// The current expression.
  final QueryExpression expression;

  const QueryState({required this.expression});

  /// Create a new [QueryState] with an initial expression.
  factory QueryState.initial(QueryExpression? initialExpression) =>
      QueryState(expression: initialExpression ?? QueryExpression.empty());

  /// Copy the state with a new expression.
  QueryState copyWith({QueryExpression? expression}) {
    return QueryState(expression: expression ?? this.expression);
  }
}

/// A BLoC for managing a query expression.
class QueryBloc extends Bloc<QueryEvent, QueryState> {
  QueryBloc([QueryExpression? initialExpression]) : super(QueryState.initial(initialExpression)) {
    on<AddQuery>(_onAddQuery);
    on<RemoveQuery>(_onRemoveQuery);
    on<UpdateEqualityQuery>(_onUpdateEqualityQuery);
    on<ReparentQuery>(_onReparentQuery);
    on<UpdateQueryOperator>(_onUpdateQueryOperator);
    on<SetQueryExpression>(_onSetQueryExpression);
    on<ConnectQueries>(_onConnectQueries);
  }

  /// Add a query to the expression.
  void _onAddQuery(AddQuery event, Emitter<QueryState> emit) {
    final updatedExpression = state.expression.addNode(event.query, parentId: event.parentId);
    emit(state.copyWith(expression: updatedExpression));
  }

  /// Remove a query from the expression.
  void _onRemoveQuery(RemoveQuery event, Emitter<QueryState> emit) {
    final updatedExpression = state.expression.removeNode(event.queryId);
    emit(state.copyWith(expression: updatedExpression));
  }

  /// Update an [EqualityQuery].
  void _onUpdateEqualityQuery(UpdateEqualityQuery event, Emitter<QueryState> emit) {
    final currentQuery = state.expression.nodes[event.id] as EqualityQuery?;
    if (currentQuery == null) {
      throw StateError('Query with id ${event.id} not found');
    }

    final updatedQuery = EqualityQuery(
      id: event.id,
      field: event.field,
      leftOperator: event.leftOperator,
      leftValue: event.leftValue,
      rightOperator: event.rightOperator,
      rightValue: event.rightValue,
    );

    final updatedExpression = state.expression.updateNode(updatedQuery);
    emit(state.copyWith(expression: updatedExpression));
  }

  /// Reparent a query.
  void _onReparentQuery(ReparentQuery event, Emitter<QueryState> emit) {
    final updatedExpression = state.expression.reparentNode(event.queryId, event.newParentId);
    emit(state.copyWith(expression: updatedExpression));
  }

  /// Update the operator of a [ParentQuery].
  void _onUpdateQueryOperator(UpdateQueryOperator event, Emitter<QueryState> emit) {
    final currentQuery = state.expression.nodes[event.id] as ParentQuery?;
    if (currentQuery == null) {
      throw StateError('Query with id ${event.id} not found');
    }

    final updatedQuery = ParentQuery(
      id: event.id,
      operator: event.newOperator,
    );

    final updatedExpression = state.expression.updateNode(updatedQuery);
    emit(state.copyWith(expression: updatedExpression));
  }

  /// Set the expression of the query.
  void _onSetQueryExpression(SetQueryExpression event, Emitter<QueryState> emit) {
    emit(state.copyWith(expression: event.expression));
  }

  /// Connect two queries with an operator.
  void _onConnectQueries(ConnectQueries event, Emitter<QueryState> emit) {
    final updatedExpression = state.expression.connectQueries(event.targetId, event.queryId, event.operator);
    emit(state.copyWith(expression: updatedExpression));
  }
}
