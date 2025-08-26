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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/error.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/bloc.dart';
import 'package:rubintv_visualization/query/primitives.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// Callback to update a series when a query is updated.
typedef SeriesQueryCallback = void Function(QueryExpression? query);

/// Callback to update an [EqualityOperator] in an [EqualityQueryWidget].
typedef UpdateEqualityOperatorCallback = void Function(EqualityOperator? operator);

/// Callback to update a [QueryOperator] in an [EqualityQueryWidget].
typedef UpdateQueryOperatorCallback = void Function(QueryOperator? operator);

/// [TextField] to update the left or write value in an [EqualityQuery].
class ValueTextField extends StatefulWidget {
  /// The initial value of the text field.
  final dynamic initialValue;

  /// Whether the text field is for the left or right value.
  final bool isLeft;

  /// The [EqualityQuery] to update.
  final EqualityQuery query;

  /// The ID of the [EqualityQuery] to update.
  final UniqueId queryId;
  //// The theme to use for the text field.
  final AppTheme theme;

  const ValueTextField({
    super.key,
    required this.initialValue,
    required this.isLeft,
    required this.query,
    required this.queryId,
    required this.theme,
  });

  @override
  ValueTextFieldState createState() => ValueTextFieldState();
}

/// State for the [ValueTextField] widget.
class ValueTextFieldState extends State<ValueTextField> {
  /// The controller for the text field.
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Update the [QueryBloc] with the new value.
  void _updateQuery(String newValue) {
    context.read<QueryBloc>().add(
          UpdateEqualityQuery(
            id: widget.queryId,
            field: widget.query.field,
            leftValue: widget.isLeft ? newValue : widget.query.leftValue,
            rightValue: widget.isLeft ? widget.query.rightValue : newValue,
            leftOperator: widget.query.leftOperator,
            rightOperator: widget.query.rightOperator,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: TextField(
        controller: _controller,
        decoration: widget.theme.queryTextDecoration,
        onChanged: (value) {
          _updateQuery(value);
        },
        onEditingComplete: () {
          _updateQuery(_controller.text);
        },
        onSubmitted: (value) {
          _updateQuery(value);
        },
      ),
    );
  }
}

/// Widget to display an [EqualityOperator] in an [EqualityQueryWidget].
class EqualityOperatorWidget extends StatelessWidget {
  /// The theme to use for the widget.
  final AppTheme theme;

  /// The operator to edit.
  final EqualityOperator operator;

  /// The available operators to choose from.
  final Set<EqualityOperator> availableOperators;

  /// Callback to update the operator.
  final UpdateEqualityOperatorCallback updateEqualityOperatorCallback;

  const EqualityOperatorWidget({
    super.key,
    required this.theme,
    required this.operator,
    required this.availableOperators,
    required this.updateEqualityOperatorCallback,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<EqualityOperator>(
      value: operator,
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      items: availableOperators
          .map((EqualityOperator op) => DropdownMenuItem(
                value: op,
                child: Container(
                  constraints: const BoxConstraints(minWidth: kMinInteractiveDimension),
                  child: Text(
                    op.symbol,
                    style: theme.queryOperatorStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ))
          .toList(),
      onChanged: (EqualityOperator? value) {
        updateEqualityOperatorCallback(value);
      },
      icon: Visibility(
        visible: operator == EqualityOperator.blank,
        child: const Icon(Icons.arrow_drop_down_outlined),
      ),
      iconEnabledColor: theme.themeData.primaryColorDark,
    );
  }
}

/// [Widget] to display an [EqualityQuery]
class EqualityQueryWidget extends StatelessWidget {
  /// The theme to use for the widget.
  final AppTheme theme;

  /// The ID of the query to edit.
  final UniqueId queryId;

  const EqualityQueryWidget({
    super.key,
    required this.theme,
    required this.queryId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QueryBloc, QueryState>(
      builder: (context, state) {
        final query = state.expression.nodes[queryId] as EqualityQuery?;
        if (query == null) return const SizedBox();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (query.leftValue != null) ...[
              ValueTextField(
                initialValue: query.leftValue,
                isLeft: true,
                query: query,
                queryId: queryId,
                theme: theme,
              ),
              SizedBox(width: theme.querySpacerWidth),
            ],
            if (!query.field.isString) _buildOperatorWidget(context, query.leftOperator, true, query),
            SizedBox(width: theme.querySpacerWidth),
            Text(query.field.name, style: theme.queryStyle),
            SizedBox(width: theme.querySpacerWidth),
            _buildOperatorWidget(context, query.rightOperator, false, query),
            SizedBox(width: theme.querySpacerWidth),
            if (query.rightValue != null)
              ValueTextField(
                initialValue: query.rightValue,
                isLeft: false,
                query: query,
                queryId: queryId,
                theme: theme,
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => context.read<QueryBloc>().add(RemoveQuery(queryId)),
            ),
          ],
        );
      },
    );
  }

  /// Build the operator widget for the query.
  Widget _buildOperatorWidget(
      BuildContext context, EqualityOperator? operator, bool isLeft, EqualityQuery query) {
    Set<EqualityOperator> availableOperators = isLeft
        ? const {EqualityOperator.lt, EqualityOperator.le, EqualityOperator.blank}
        : const {
            EqualityOperator.eq,
            EqualityOperator.ne,
            EqualityOperator.lt,
            EqualityOperator.le,
            EqualityOperator.blank,
            EqualityOperator.startswith,
            EqualityOperator.endswith,
            EqualityOperator.contains,
          };

    return EqualityOperatorWidget(
      theme: theme,
      operator: operator ?? EqualityOperator.blank,
      availableOperators: availableOperators,
      updateEqualityOperatorCallback: (EqualityOperator? newOperator) {
        dynamic leftValue = isLeft
            ? query.leftValue ?? query.field.bounds == null
                ? 0
                : query.field.bounds!.min
            : query.leftValue;
        dynamic rightValue = isLeft
            ? query.rightValue
            : query.rightValue ?? query.field.bounds == null
                ? 0
                : query.field.bounds!.max;
        context.read<QueryBloc>().add(
              UpdateEqualityQuery(
                id: queryId,
                field: query.field,
                leftOperator: isLeft ? newOperator : query.leftOperator,
                rightOperator: isLeft ? query.rightOperator : newOperator,
                leftValue: leftValue,
                rightValue: rightValue,
              ),
            );
      },
    );
  }
}

/// Widget to display an [EqualityOperator] in an [EqualityQueryWidget].
class QueryOperatorWidget extends StatelessWidget {
  /// The theme to use for the widget.
  final AppTheme theme;

  /// The operator to edit.
  final QueryOperator operator;

  /// The available operators to choose from.
  final Set<QueryOperator> availableOperators;

  /// Callback to update the operator.
  final UpdateQueryOperatorCallback updateQueryOperatorCallback;

  const QueryOperatorWidget({
    super.key,
    required this.theme,
    required this.operator,
    required this.availableOperators,
    required this.updateQueryOperatorCallback,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButton<QueryOperator>(
      value: operator,
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      items: availableOperators
          .map((QueryOperator op) => DropdownMenuItem(
                value: op,
                child: Container(
                  constraints: const BoxConstraints(minWidth: kMinInteractiveDimension),
                  child: Text(
                    op.symbol,
                    style: theme.queryOperatorStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ))
          .toList(),
      onChanged: (QueryOperator? value) {
        updateQueryOperatorCallback(value);
      },
      icon: const Icon(Icons.arrow_drop_down_outlined),
      iconEnabledColor: theme.themeData.primaryColorDark,
    );
  }
}

/// Widget to display a [ParentQuery] and all of its children.
class ParentQueryWidget extends StatelessWidget {
  /// The theme to use for the widget.
  final AppTheme theme;

  /// The ID of the query to edit.
  final UniqueId queryId;

  /// The depth of the query in the tree.
  final int depth;

  const ParentQueryWidget({
    super.key,
    required this.theme,
    required this.queryId,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QueryBloc, QueryState>(
      builder: (context, state) {
        final query = state.expression.nodes[queryId] as ParentQuery?;
        if (query == null) return const SizedBox();

        List<Widget> children = state.expression.children[queryId]
                ?.map(
                  (childId) => QueryWidget(
                    theme: theme,
                    queryId: childId,
                    depth: depth + 1,
                  ),
                )
                .toList() ??
            [];

        return Row(
          children: [
            QueryOperatorWidget(
              theme: theme,
              operator: query.operator,
              availableOperators: const {
                QueryOperator.and,
                QueryOperator.or,
                QueryOperator.xor,
                QueryOperator.blank
              },
              updateQueryOperatorCallback: (QueryOperator? newOperator) {
                if (newOperator == QueryOperator.blank) {
                  context.read<QueryBloc>().add(RemoveQuery(queryId));
                } else if (newOperator != null) {
                  context.read<QueryBloc>().add(UpdateQueryOperator(queryId, newOperator));
                }
              },
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ],
        );
      },
    );
  }
}

/// Widget to create a new query.
class NewQueryWidget extends StatefulWidget {
  /// The theme to use for the widget.
  final AppTheme theme;

  /// The database schema to use for the widget.
  final DatabaseSchema database;

  const NewQueryWidget({
    super.key,
    required this.theme,
    required this.database,
  });

  @override
  NewQueryWidgetState createState() => NewQueryWidgetState();
}

/// State for the [NewQueryWidget] widget.
class NewQueryWidgetState extends State<NewQueryWidget> {
  /// The currently selected table.
  TableSchema? _table;

  /// The currently selected column.
  SchemaField? _field;

  @override
  void initState() {
    super.initState();
    _table = widget.database.tables.values.first;
    _field = _table!.fields.values.first;
  }

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<TableSchema>> tableEntries = widget.database.tables.entries
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
        .toList();

    List<DropdownMenuItem<SchemaField>> columnEntries =
        _table?.fields.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList() ?? [];

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        decoration: BoxDecoration(
          color: widget.theme.themeData.colorScheme.surface,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<TableSchema>(
              value: _table,
              items: tableEntries,
              onChanged: (TableSchema? newTable) {
                setState(() {
                  _table = newTable;
                  _field = _table!.fields.values.first;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButton<SchemaField>(
              value: _field,
              items: columnEntries,
              onChanged: (SchemaField? newField) {
                setState(() {
                  _field = newField ?? _table!.fields.values.first;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              tooltip: "Create query entry for '$_field'",
              onPressed: () {
                if (_field != null) {
                  context.read<QueryBloc>().add(
                        AddQuery(
                          EqualityQuery(
                            id: UniqueId.next(),
                            field: _field!,
                          ),
                        ),
                      );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to edit a query expression.
class QueryEditor extends StatelessWidget {
  /// The theme to use for the widget.
  final AppTheme theme;

  /// The database schema to use for the widget.
  final DatabaseSchema database;

  /// Callback to call when the query is completed.
  final SeriesQueryCallback onCompleted;

  const QueryEditor({
    super.key,
    required this.theme,
    required this.onCompleted,
    required this.database,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QueryBloc, QueryState>(
      builder: (context, state) {
        return Form(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...state.expression.roots.map(
                  (queryId) => QueryWidget(
                    theme: theme,
                    queryId: queryId,
                    depth: 0,
                  ),
                ),
                NewQueryWidget(theme: theme, database: database),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.cancel, color: Colors.red),
                    ),
                    IconButton(
                      onPressed: () {
                        if (state.expression.roots.isEmpty) {
                          onCompleted(null);
                          Navigator.pop(context);
                        } else if (state.expression.roots.length > 1) {
                          // Show error: "Unconnected queries"
                          reportError("Error: Unconnected queries");
                        } else if (state.expression.isValid()) {
                          onCompleted(state.expression);
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget to display an editable query.
class QueryWidget extends StatelessWidget {
  /// The theme to use for the widget.
  final AppTheme theme;

  /// The ID of the query to edit.
  final UniqueId queryId;

  /// The depth of the query in the tree.
  final int depth;

  const QueryWidget({
    super.key,
    required this.theme,
    required this.queryId,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<QueryBloc, QueryState>(
      builder: (context, state) {
        final query = state.expression.nodes[queryId];
        if (query == null) return const SizedBox();

        final child = query is EqualityQuery
            ? EqualityQueryWidget(theme: theme, queryId: queryId)
            : ParentQueryWidget(theme: theme, queryId: queryId, depth: depth);

        return DragTarget<UniqueId>(
          onWillAcceptWithDetails: (details) => details.data != queryId,
          onAcceptWithDetails: (details) {
            context.read<QueryBloc>().add(ConnectQueries(
                  targetId: queryId,
                  queryId: details.data,
                  operator: QueryOperator.and,
                ));
          },
          builder: (context, candidateData, rejectedData) {
            return AnimatedContainer(
              margin: EdgeInsets.all(theme.querySpacerWidth / 2),
              decoration: BoxDecoration(
                color: query is EqualityQuery
                    ? theme.themeData.colorScheme.primaryContainer
                    : theme.operatorQueryColor(depth),
                borderRadius: BorderRadius.circular(10),
              ),
              duration: theme.animationSpeed,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Draggable<UniqueId>(
                    data: queryId,
                    feedback: _buildDragFeedback(theme),
                    childWhenDragging: _buildDragChildWhenDragging(theme),
                    child: _buildDragChild(theme, candidateData.isNotEmpty),
                  ),
                  SizedBox(width: theme.querySpacerWidth),
                  child,
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Build the drag feedback widget.
  Widget _buildDragFeedback(AppTheme theme) {
    return Center(
      child: Container(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        decoration: BoxDecoration(
          color: theme.themeData.colorScheme.secondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Dim the dragged child when it is being dragged.
  Widget _buildDragChildWhenDragging(AppTheme theme) {
    return Center(
      child: Container(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        decoration: BoxDecoration(
          color: theme.themeData.colorScheme.secondary.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Build the drag child widget.
  Widget _buildDragChild(AppTheme theme, bool isAccepted) {
    return Center(
      child: Container(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        decoration: BoxDecoration(
          color: isAccepted ? theme.wireColor : theme.themeData.colorScheme.secondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
