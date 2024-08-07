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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/query/update.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// Callback to update a series when a query is updated.
typedef SeriesQueryCallback = void Function(Query? query);

/// Callback to update an [EqualityOperator] in an [EqualityQueryWidget].
typedef UpdateEqualityOperatorCallback = void Function(EqualityOperator? operator);

/// Callback to update a [QueryOperator] in an [EqualityQueryWidget].
typedef UpdateQueryOperatorCallback = void Function(QueryOperator? operator);

/// Widget to display an [EqualityOperator] in an [EqualityQueryWidget].
class EqualityOperatorWidget extends StatefulWidget {
  /// Theme for the app.
  final AppTheme theme;

  /// Operator to display
  final EqualityOperator operator;

  /// Available operators to select from.
  /// This is different depending on whether this is a left or right operator,
  /// and the data type
  final Set<EqualityOperator> availableOperators;

  /// Callback to the [EqualityQueryWidget] to update the operator.
  final UpdateEqualityOperatorCallback updateEqualityOperatorCallback;

  const EqualityOperatorWidget({
    super.key,
    required this.theme,
    required this.operator,
    required this.availableOperators,
    required this.updateEqualityOperatorCallback,
  });

  @override
  EqualityOperatorWidgetState createState() => EqualityOperatorWidgetState();
}

/// [State] for an [EqualityOperatorWidget].
class EqualityOperatorWidgetState extends State<EqualityOperatorWidget> {
  EqualityOperator? selectedOperator = EqualityOperator.blank;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<EqualityOperator>(
      value: selectedOperator,
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      items: widget.availableOperators
          .map((EqualityOperator operator) => DropdownMenuItem(
                value: operator,
                child: Container(
                  constraints: const BoxConstraints(minWidth: kMinInteractiveDimension),
                  child: Text(
                    operator.symbol,
                    style: widget.theme.queryOperatorStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ))
          .toList(),
      onChanged: (EqualityOperator? value) {
        setState(() {
          selectedOperator = value;
          widget.updateEqualityOperatorCallback(value);
        });
      },
      icon: Visibility(
          visible: selectedOperator == EqualityOperator.blank,
          child: const Icon(Icons.arrow_drop_down_outlined)),
      iconEnabledColor: widget.theme.themeData.primaryColorDark,
    );
  }
}

/// [Widget] to display an [EqualityQuery]
class EqualityQueryWidget extends StatefulWidget {
  /// Theme for the app.
  final AppTheme theme;

  /// The [EqualityQuery] to display.
  final EqualityQuery query;

  /// The dispatcher for query updates.
  final QueryUpdateCallback dispatch;

  const EqualityQueryWidget({
    super.key,
    required this.theme,
    required this.query,
    required this.dispatch,
  });

  @override
  EqualityQueryWidgetState createState() => EqualityQueryWidgetState();
}

/// [State] for am [EqualityQueryWidget].
class EqualityQueryWidgetState extends State<EqualityQueryWidget> {
  /// [TextEditingController] for the left value (if a left [EqualityOperator] exists.
  TextEditingController? leftController;

  /// [TextEditingController] for the right value (if a right [EqualityOperator] exists.
  TextEditingController? rightController;

  /// Shortcut to [EqualityQueryWidget.query].
  EqualityQuery get query => widget.query;

  /// Shortcut to [EqualityQueryWidget.theme].
  AppTheme get theme => widget.theme;

  /// Update the left condition in the [EqualityQuery].
  void addLeftCondition(EqualityOperator? operator) {
    if (operator == null) {
      query.leftValue = null;
      query.leftOperator = null;
    } else {
      query.leftOperator = operator;
      query.leftValue = query.field.bounds == null ? 0 : query.field.bounds!.max;
    }
    widget.dispatch(const QueryUpdate());
    setState(() {});
  }

  /// Update the right condition in the [EqualityQuery].
  void addRightCondition(EqualityOperator? operator) {
    if (operator == null) {
      query.rightValue = null;
      query.rightOperator = null;
    } else {
      query.rightOperator = operator;
      query.rightValue = query.field.bounds == null ? 0 : query.field.bounds!.min;
    }
    widget.dispatch(const QueryUpdate());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [];
    if (query.leftValue != null) {
      // Add a TextField for the left (<, <=) condition
      leftController ??= TextEditingController(text: query.leftValue!.toString());
      children.add(SizedBox(
        width: 100,
        child: TextField(
          controller: leftController,
          decoration: theme.queryTextDecoration,
          onChanged: (String value) {
            setState(() {
              query.leftValue = value;
            });
          },
        ),
      ));
      children.add(SizedBox(width: theme.querySpacerWidth));
    }

    if (!query.field.isString) {
      // Numbers and dates can have a left condition, so add an operator here
      children.add(EqualityOperatorWidget(
        theme: theme,
        operator: EqualityOperator.blank,
        availableOperators: const {EqualityOperator.lt, EqualityOperator.lte, EqualityOperator.blank},
        updateEqualityOperatorCallback: addLeftCondition,
      ));
    }

    // Add the label for the column field
    children.add(SizedBox(width: theme.querySpacerWidth));
    children.add(Text(query.field.name, style: theme.queryStyle));
    children.add(SizedBox(width: theme.querySpacerWidth));

    if (!query.field.isString) {
      // Numbers and dates can have <, <= operators
      children.add(EqualityOperatorWidget(
        theme: theme,
        operator: EqualityOperator.blank,
        availableOperators: const {
          EqualityOperator.eq,
          EqualityOperator.neq,
          EqualityOperator.lt,
          EqualityOperator.lte,
          EqualityOperator.blank
        },
        updateEqualityOperatorCallback: addRightCondition,
      ));
    } else {
      // Strings can only have = and != operators and string operators
      children.add(EqualityOperatorWidget(
        theme: theme,
        operator: EqualityOperator.blank,
        availableOperators: const {
          EqualityOperator.eq,
          EqualityOperator.neq,
          EqualityOperator.blank,
          EqualityOperator.startsWith,
          EqualityOperator.endsWith,
          EqualityOperator.contains,
        },
        updateEqualityOperatorCallback: addRightCondition,
      ));
    }
    children.add(SizedBox(width: theme.querySpacerWidth));

    if (query.rightValue != null) {
      // Create a TextField for the right condition value
      rightController ??= TextEditingController(text: query.rightValue!.toString());
      children.add(SizedBox(
        width: 100,
        child: TextField(
          controller: rightController,
          decoration: theme.queryTextDecoration,
          onChanged: (String value) {
            setState(() {
              query.rightValue = value;
            });
          },
        ),
      ));
    }

    // Add a trash can button to delete this query
    children.add(IconButton(
      icon: const Icon(Icons.delete, color: Colors.redAccent),
      onPressed: () {
        widget.dispatch(RemoveQuery(query: query));
      },
    ));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

/// Widget to display an [EqualityOperator] in an [EqualityQueryWidget].
class QueryOperatorWidget extends StatefulWidget {
  /// Theme for the app.
  final AppTheme theme;

  /// Operator to display
  final QueryOperator operator;

  /// Available operators to select from.
  /// This is different depending on whether this is a left or right operator,
  /// and the data type
  final Set<QueryOperator> availableOperators;

  /// Callback to the [EqualityQueryWidget] to update the operator.
  final UpdateQueryOperatorCallback updateQueryOperatorCallback;

  const QueryOperatorWidget({
    super.key,
    required this.theme,
    required this.operator,
    required this.availableOperators,
    required this.updateQueryOperatorCallback,
  });

  @override
  QueryOperatorWidgetState createState() => QueryOperatorWidgetState();
}

/// [State] for an [EqualityOperatorWidget].
class QueryOperatorWidgetState extends State<QueryOperatorWidget> {
  @override
  Widget build(BuildContext context) {
    return DropdownButton<QueryOperator>(
      value: widget.operator,
      borderRadius: const BorderRadius.all(Radius.circular(5)),
      items: widget.availableOperators
          .map((QueryOperator operator) => DropdownMenuItem(
                value: operator,
                child: Container(
                  constraints: const BoxConstraints(minWidth: kMinInteractiveDimension),
                  child: Text(
                    operator.symbol,
                    style: widget.theme.queryOperatorStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ))
          .toList(),
      onChanged: (QueryOperator? value) {
        setState(() {
          widget.updateQueryOperatorCallback(value);
        });
      },
      icon: const Icon(Icons.arrow_drop_down_outlined),
      iconEnabledColor: widget.theme.themeData.primaryColorDark,
    );
  }
}

/// Widget to display a [QueryOperation] and all of its children.
class QueryOperationWidget extends StatefulWidget {
  /// Theme for the app.
  final AppTheme theme;

  /// The [QueryOperation] instance that this [Widget] displays.
  final QueryOperation query;

  /// Callback to pass a [QueryUpdate].
  final QueryUpdateCallback dispatch;

  /// The depth of this query in the tree
  /// (used to alternate the [Container] [Color].
  final int depth;

  const QueryOperationWidget({
    super.key,
    required this.theme,
    required this.query,
    required this.dispatch,
    required this.depth,
  });

  @override
  QueryOperationWidgetState createState() => QueryOperationWidgetState();
}

class QueryOperationWidgetState extends State<QueryOperationWidget> {
  AppTheme get theme => widget.theme;
  QueryOperation get query => widget.query;
  QueryUpdateCallback get dispatch => widget.dispatch;

  /// Update the operator for this query
  void updateOperator(QueryOperator? operator) {
    if (operator == QueryOperator.blank) {
      dispatch(RemoveQuery(query: query, keepChildren: true));
    }
    if (operator != query.operator) {
      setState(() {
        query.operator = operator!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = query.children
        .map((Query q) => QueryWidget(theme: theme, dispatch: dispatch, depth: widget.depth + 1, query: q))
        .toList();

    return Row(
      children: [
        // allow the user to select an operator
        QueryOperatorWidget(
            theme: theme,
            operator: query.operator,
            availableOperators: const {
              QueryOperator.and,
              QueryOperator.or,
              QueryOperator.xor,
              QueryOperator.blank
            },
            updateQueryOperatorCallback: updateOperator),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        )
      ],
    );
  }
}

/// Allow the user to select available columns for a query
class NewQueryWidget extends StatefulWidget {
  /// The theme for the app.
  final AppTheme theme;

  /// Dispatcher to pass updates to the full expression.
  final QueryUpdateCallback dispatch;

  const NewQueryWidget({
    super.key,
    required this.theme,
    required this.dispatch,
  });

  @override
  NewQueryWidgetState createState() => NewQueryWidgetState();
}

/// [State] for teh [NewQueryWidget].
class NewQueryWidgetState extends State<NewQueryWidget> {
  /// The currently selected [DatabaseSchema].
  DatabaseSchema? _database;

  /// The currently selected [TableSchema].
  TableSchema? _table;

  /// The currently selected [SchemaField].
  SchemaField? _field;

  @override
  Widget build(BuildContext context) {
    if (_field != null) {
      _table = _field!.schema;
      _database = _table!.database;
    } else {
      _database = DataCenter().databases.values.first;
      _table = _database!.tables.values.first;
      _field = _table!.fields.values.first;
    }

    List<DropdownMenuItem<DatabaseSchema>> databaseEntries = DataCenter()
        .databases
        .entries
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
        .toList();

    List<DropdownMenuItem<TableSchema>> tableEntries = [];
    List<DropdownMenuItem<SchemaField>> columnEntries = [];

    if (_database != null) {
      tableEntries =
          _database!.tables.entries.map((e) => DropdownMenuItem(value: e.value, child: Text(e.key))).toList();
    }

    if (_table != null) {
      columnEntries =
          _table!.fields.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
          decoration: BoxDecoration(
            color: widget.theme.themeData.colorScheme.surface,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<DatabaseSchema>(
              /*decoration: const InputDecoration(
                labelText: "Database",
                border: OutlineInputBorder(),
              ),*/
              value: _database,
              items: databaseEntries,
              onChanged: (DatabaseSchema? newDatabase) {
                setState(() {
                  _database = newDatabase;
                  _table = _database!.tables.values.first;
                  _field = _table!.fields.values.first;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButton<TableSchema>(
              /*decoration: const InputDecoration(
                labelText: "Table",
                border: OutlineInputBorder(),
              ),*/
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
              /*decoration: const InputDecoration(
                labelText: "Column",
                border: OutlineInputBorder(),
              ),*/
              value: _field,
              items: columnEntries,
              onChanged: (SchemaField? newField) {
                setState(() {
                  newField ??= _table!.fields.values.first;
                  _field = newField;
                });
              },
            ),
            IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.green),
                tooltip: "Create query entry for '$_field'",
                onPressed: () {
                  if (_field != null) {
                    widget.dispatch(AddNewQuery(column: _field!));
                    setState(() {});
                  }
                }),
          ])),
    );
  }
}

/// [Widget] to edit a full [Query] expression
class QueryEditor extends StatefulWidget {
  final AppTheme theme;
  final QueryExpression expression;
  final SeriesQueryCallback onCompleted;

  const QueryEditor({
    super.key,
    required this.theme,
    required this.expression,
    required this.onCompleted,
  });

  @override
  QueryEditorState createState() => QueryEditorState();
}

/// [State] for a [QueryEditor]/
class QueryEditorState extends State<QueryEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Shortcut to the [AppTheme]/
  AppTheme get theme => widget.theme;

  /// Shortcut to the [QueryExpression].
  QueryExpression get expression => widget.expression;

  /// Remove a query term from the expression
  void removeQuery({
    required Query query,
    required bool keepChildren,
  }) {
    if (query.parent != null) {
      QueryOperation parent = query.parent!;
      if (keepChildren && query is QueryOperation) {
        parent.addAllChildren(query.children);
      }
      parent.removeChild(query);
      if (parent.children.length == 1) {
        removeQuery(query: parent, keepChildren: true);
      }
    } else if (expression.queries.contains(query)) {
      if (keepChildren && query is QueryOperation) {
        expression.addAllQueries(query.children);
      }
      expression.removeQuery(query);
    } else {
      throw QueryError("Cannot find query '$query' in expression");
    }
    setState(() {});
  }

  /// Add a new [EqualityQuery] to the expression
  void addNewQuery(SchemaField column) {
    setState(() {
      expression.addQuery(EqualityQuery(
        id: UniqueId.next(),
        field: column,
      ));
    });
  }

  void connectQueries(ConnectQueries update) {
    Query target = update.target;
    Query query = update.query;
    if (target.parent != null) {
      if (query.parent != null) {
        query.parent!.removeChild(query);
      }
      target.parent!.addChild(query);
      expression.removeQuery(query);
    } else if (query.parent != null) {
      query.parent!.addChild(target);
      expression.removeQuery(target);
    } else {
      int targetIndex = expression.queries.indexOf(target);
      int queryIndex = expression.queries.indexOf(query);
      if (targetIndex < 0 || queryIndex < 0) {
        throw QueryError("Could not find $target and $query in unattached queries");
      }
      expression.removeQuery(target);
      expression.removeQuery(query);
      Query query1 = target;
      Query query2 = query;
      if (queryIndex < targetIndex) {
        query1 = query;
        query2 = target;
      }

      QueryOperation newQuery = QueryOperation(
        id: UniqueId.next(),
        children: [query1, query2],
        operator: update.operator,
      );

      expression.addQuery(newQuery);
    }
  }

  /// Catch [QueryUpdate] actions.
  void dispatcher(QueryUpdate update) {
    if (update is RemoveQuery) {
      removeQuery(query: update.query, keepChildren: update.keepChildren);
    } else if (update is AddNewQuery) {
      addNewQuery(update.column);
    } else if (update is ConnectQueries) {
      connectQueries(update);
    }
    setState(() {});
  }

  /// Validate the query expression before closing the editor.
  bool validate(Query? query) {
    if (query is QueryOperation) {
      if (query.children.length <= 1) {
        Fluttertoast.showToast(
            msg: "Query error",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 5,
            backgroundColor: Colors.red,
            webBgColor: "#e74c3c",
            textColor: Colors.white,
            fontSize: 16.0);
        return false;
      }
      for (Query child in query.children) {
        if (!validate(child)) {
          return false;
        }
      }
      return true;
    } else if (query is EqualityQuery) {
      if (query.leftValue == null && query.rightValue == null) {
        Fluttertoast.showToast(
            msg: "Query $query has no comparison",
            toastLength: Toast.LENGTH_LONG,
            gravity: ToastGravity.CENTER,
            timeInSecForIosWeb: 5,
            backgroundColor: Colors.red,
            webBgColor: "#e74c3c",
            textColor: Colors.white,
            fontSize: 16.0);
        return false;
      }
      return true;
    } else {
      throw UnimplementedError("Unrecognized query type ${query.runtimeType}");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> children = expression.queries
        .map<Widget>((Query query) => QueryWidget(theme: theme, dispatch: dispatcher, depth: 0, query: query))
        .toList();

    children.add(NewQueryWidget(
      theme: widget.theme,
      dispatch: dispatcher,
    ));
    children.add(Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(Icons.cancel, color: Colors.red),
        ),
        IconButton(
          onPressed: () {
            if (expression.queries.isEmpty) {
              widget.onCompleted(null);
              Navigator.pop(context);
            } else if (expression.queries.length > 1) {
              Fluttertoast.showToast(
                  msg: "Unconnected queries",
                  toastLength: Toast.LENGTH_LONG,
                  gravity: ToastGravity.CENTER,
                  timeInSecForIosWeb: 5,
                  backgroundColor: Colors.red,
                  webBgColor: "#e74c3c",
                  textColor: Colors.white,
                  fontSize: 16.0);
            } else if (validate(expression.queries.first)) {
              widget.onCompleted(expression.queries.length == 1 ? expression.queries.first : null);
              Navigator.pop(context);
            }
          },
          icon: const Icon(Icons.check_circle, color: Colors.green),
        ),
      ],
    ));

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// Widget to display a [Query] instance.
class QueryWidget extends StatefulWidget {
  /// The [Query] instance to display.
  final Query query;

  /// The theme for the app.
  final AppTheme theme;

  /// Dispatcher to pass updates to the full expression.
  final QueryUpdateCallback dispatch;

  /// The depth of this query in the tree
  final int depth;

  const QueryWidget({
    super.key,
    required this.query,
    required this.theme,
    required this.dispatch,
    required this.depth,
  });

  @override
  QueryWidgetState createState() => QueryWidgetState();
}

/// [State] for a [QueryWidget].
class QueryWidgetState extends State<QueryWidget> {
  /// Shortcut to the [QueryWidget.query].
  AppTheme get theme => widget.theme;

  /// [Widget] to display if a query field is being dragged.
  OverlayEntry? wireWidget;

  /// The initial position of the drag.
  late Offset initialPosition;

  /// The current position of the drag.
  late Offset currentPosition;

  /// The color to use for this query (which depends on the operator)
  Color get color => widget.query is EqualityQuery
      ? theme.themeData.colorScheme.primaryContainer
      : theme.operatorQueryColor(widget.depth);

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (widget.query is EqualityQuery) {
      child = EqualityQueryWidget(
        theme: theme,
        query: widget.query as EqualityQuery,
        dispatch: widget.dispatch,
      );
    } else if (widget.query is QueryOperation) {
      child = QueryOperationWidget(
        theme: theme,
        query: widget.query as QueryOperation,
        dispatch: widget.dispatch,
        depth: widget.depth,
      );
    } else {
      throw UnimplementedError("Unrecognized query type ${widget.query}");
    }
    return DragTarget<Query>(
      onWillAcceptWithDetails: (DragTargetDetails<Query?> details) =>
          details.data != null && details.data != widget.query,
      onAcceptWithDetails: (DragTargetDetails<Query?> details) {
        Query? query = details.data;
        if (query != null) {
          widget.dispatch(ConnectQueries(
            target: widget.query,
            query: query,
          ));
        }
      },
      builder: (
        BuildContext context,
        List<dynamic> accepted,
        List<dynamic> rejected,
      ) =>
          AnimatedContainer(
        margin: EdgeInsets.all(theme.querySpacerWidth / 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        duration: theme.animationSpeed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Draggable<Query>(
              data: widget.query,
              feedback: Center(
                  child: Container(
                width: kMinInteractiveDimension,
                height: kMinInteractiveDimension,
                decoration: BoxDecoration(
                  color: theme.themeData.colorScheme.secondary,
                  shape: BoxShape.circle,
                ),
              )),
              childWhenDragging: Center(
                child: Container(
                  width: kMinInteractiveDimension,
                  height: kMinInteractiveDimension,
                  decoration: BoxDecoration(
                    color: theme.themeData.colorScheme.secondary.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              child: Center(
                child: Container(
                  width: kMinInteractiveDimension,
                  height: kMinInteractiveDimension,
                  decoration: BoxDecoration(
                    color: accepted.isEmpty ? theme.themeData.colorScheme.secondary : theme.wireColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            SizedBox(width: theme.querySpacerWidth),
            child,
          ],
        ),
      ),
    );
  }
}

/// [CustomPainter] to draw a wire between two [Query] instances.
class WirePainter extends CustomPainter {
  /// The theme for the app.
  final AppTheme theme;

  /// The initial position of the wire.
  final Offset initialPosition;

  /// The final position of the wire.
  final Offset currentPosition;

  WirePainter({
    required this.theme,
    required this.initialPosition,
    required this.currentPosition,
  });

  /// Paint the wire between the two positions.
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.wireThickness
      ..color = theme.wireColor;

    canvas.drawLine(initialPosition, currentPosition, paint);
  }

  /// Check if the wire should be repainted.
  @override
  bool shouldRepaint(WirePainter oldDelegate) =>
      initialPosition != oldDelegate.initialPosition ||
      currentPosition != oldDelegate.currentPosition ||
      theme != oldDelegate.theme;
}

/// [Widget] to display a wire between two [Query] instances.
class WireWidget extends StatelessWidget {
  /// The theme for the app.
  final AppTheme theme;

  /// The initial position where the wire starts.
  final Offset initialPosition;

  /// The current position of the end of the wire (the cursor).
  final Offset currentPosition;

  const WireWidget({
    super.key,
    required this.theme,
    required this.initialPosition,
    required this.currentPosition,
  });

  @override
  Widget build(BuildContext context) {
    Offset topLeft = Offset(
      math.min(initialPosition.dx, currentPosition.dx),
      math.min(initialPosition.dy, currentPosition.dy),
    );
    Offset bottomRight = Offset(
      math.max(initialPosition.dx, currentPosition.dx),
      math.max(initialPosition.dy, currentPosition.dy),
    );
    return Positioned(
      left: math.min(initialPosition.dx, currentPosition.dx),
      top: math.min(initialPosition.dy, currentPosition.dy),
      child: SizedBox(
          width: bottomRight.dx - topLeft.dx,
          height: bottomRight.dy - topLeft.dy,
          child: CustomPaint(
            painter: WirePainter(
              theme: theme,
              initialPosition: initialPosition - topLeft,
              currentPosition: currentPosition - topLeft,
            ),
          )),
    );
  }
}
