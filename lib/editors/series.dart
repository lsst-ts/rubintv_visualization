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

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/query/bloc.dart';
import 'package:rubintv_visualization/query/primitives.dart';
import 'package:rubintv_visualization/query/widget.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';

/// A callback function that is called when the series query is updated.
typedef SeriesQueryCallback = void Function(Query? query);

/// A [Widget] used to edit a [SeriesInfo] object.
class SeriesEditor extends StatefulWidget {
  /// The [AppTheme] used to style the editor.
  final AppTheme theme;

  /// The [SeriesInfo] object to edit.
  final SeriesInfo series;

  /// The [WorkspaceViewerState] object that contains the series.
  final WorkspaceViewerState workspace;

  /// The [ChartBloc] used to update the series.
  final ChartBloc chartBloc;

  /// The [DatabaseSchema] used to populate the editor.
  final DatabaseSchema databaseSchema;

  const SeriesEditor({
    super.key,
    required this.theme,
    required this.series,
    required this.workspace,
    required this.chartBloc,
    required this.databaseSchema,
  });

  @override
  SeriesEditorState createState() => SeriesEditorState();
}

/// The [State] object for the [SeriesEditor] widget.
class SeriesEditorState extends State<SeriesEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  AppTheme get theme => widget.theme;
  late SeriesInfo series;

  /// [TextEditingController] for the series name.
  TextEditingController nameController = TextEditingController();

  /// Create a collection of [SeriesInfo] based on unique values of the [groupName] column.
  SchemaField? groupByColumn;

  @override
  void initState() {
    super.initState();
    series = widget.series.copy();
    nameController.text = series.name;
  }

  /// Update the series query.
  void updateQuery(QueryExpression? query) {
    series = series.copyWithQuery(query);
  }

  /// Update a column in the series.
  void updateColumn(SchemaField? column, int index) {
    Map<AxisId, SchemaField> fields = {...series.fields};
    AxisId key = fields.keys.toList()[fields.values.toList().indexOf(column!)];
    fields[key] = column;
    series = series.copyWith(fields: fields);
  }

  @override
  Widget build(BuildContext context) {
    developer.log("Series is $series", name: "rubinTV.visualization.editors.series");

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 600,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nameController,
              onChanged: (String value) {
                series = series.copyWith(name: value);
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                label: Text("name"),
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return "The series must have a name";
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            ColumnEditorFormField(
              theme: theme,
              initialValue: series.fields,
              onSaved: (Map<AxisId, SchemaField?>? fields) {
                if (fields == null) return;
                Map<AxisId, SchemaField> nonNullFields = {};
                for (MapEntry<AxisId, SchemaField?> entry in fields.entries) {
                  if (entry.value == null) {
                    return;
                  }
                  nonNullFields[entry.key] = entry.value!;
                }
                series = series.copyWith(fields: nonNullFields);
              },
              validator: (Map<AxisId, SchemaField?>? fields) {
                if (fields == null || fields.values.any((e) => e == null)) {
                  return "All fields in the series must be initialized!";
                }
                return null;
              },
              databaseSchema: widget.databaseSchema,
            ),
            const SizedBox(height: 10),
            /*DropdownButtonFormField<String>(
                  value: groupByColumn,
                  items: groupNameEntries,
                  decoration: widget.theme.queryTextDecoration.copyWith(
                    labelText: "group by",
                  ),
                  onChanged: (String? columnName) {
                    setState(() {
                      groupByColumn = columnName;
                    });
                  },
                ),*/
            Row(
              children: [
                Tooltip(
                    message: "Edit query",
                    child: IconButton(
                      onPressed: () {
                        showDialog(
                            context: context,
                            builder: (BuildContext context) => Dialog(
                                  child: BlocProvider(
                                    create: (BuildContext context) => QueryBloc(series.query),
                                    child: QueryEditor(
                                      theme: theme,
                                      onCompleted: updateQuery,
                                      database:
                                          DataCenter().databases[widget.workspace.info!.instrument!.schema]!,
                                    ),
                                  ),
                                ));
                      },
                      icon: const Icon(Icons.query_stats),
                    )),
                const Spacer(),
                Tooltip(
                    message: "Delete Series",
                    child: IconButton(
                      onPressed: () {
                        widget.chartBloc.add(DeleteSeriesEvent(series.id));
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                    )),
                Tooltip(
                    message: "Cancel",
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.cancel, color: Colors.red),
                    )),
                Tooltip(
                    message: "Aceept",
                    child: IconButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          widget.chartBloc.add(UpdateSeriesEvent(
                            series: series,
                            groupByColumn: groupByColumn,
                            dayObs: getFormattedDate(widget.workspace.info!.dayObs),
                            globalQuery: widget.workspace.info!.globalQuery,
                          ));
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                    )),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

/// A [FormField] used to edit a collection columns in a series.
class ColumnEditorFormField extends FormField<Map<AxisId, SchemaField?>> {
  /// The [AppTheme] used to style the editor.
  final AppTheme theme;

  /// The [DatabaseSchema] used to populate the editor.
  final DatabaseSchema databaseSchema;

  ColumnEditorFormField({
    super.key,
    required this.theme,
    required FormFieldSetter<Map<AxisId, SchemaField?>> onSaved,
    required FormFieldValidator<Map<AxisId, SchemaField?>> validator,
    required Map<AxisId, SchemaField?> initialValue,
    required this.databaseSchema,
    bool autovalidate = false,
  }) : super(
            onSaved: onSaved,
            validator: validator,
            initialValue: initialValue,
            builder: (FormFieldState<Map<AxisId, SchemaField?>> formState) {
              return SizedBox(
                child: ListView.builder(
                  itemCount: initialValue.length,
                  shrinkWrap: true,
                  itemBuilder: (BuildContext context, int index) {
                    AxisId axisId = initialValue.keys.toList()[index];
                    return Container(
                        margin: const EdgeInsets.all(10),
                        child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: "axis $index",
                              border: const OutlineInputBorder(),
                            ),
                            child: ColumnEditor(
                              theme: theme,
                              initialValue: initialValue[axisId]!,
                              onChanged: (SchemaField? field) {
                                Map<AxisId, SchemaField?> fields = {...formState.value!};
                                fields[axisId] = field;
                                formState.didChange(fields);
                              },
                              databaseSchema: databaseSchema,
                            )));
                  },
                ),
              );
            });
}

/// A [StatefulWidget] used to edit a column in a series.
class ColumnEditor extends StatefulWidget {
  /// The [AppTheme] used to style the editor.
  final AppTheme theme;

  /// A callback function that is called when the column is updated.
  final ValueChanged<SchemaField?> onChanged;

  /// The initial value of the column.
  final SchemaField initialValue;

  /// The [DatabaseSchema] used to populate the editor.
  final DatabaseSchema databaseSchema;

  const ColumnEditor({
    super.key,
    required this.theme,
    required this.onChanged,
    required this.initialValue,
    required this.databaseSchema,
  });

  @override
  ColumnEditorState createState() => ColumnEditorState();
}

/// The [State] object for the [ColumnEditor] widget.
class ColumnEditorState extends State<ColumnEditor> {
  AppTheme get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _field = widget.initialValue;
  }

  @override
  void didUpdateWidget(ColumnEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _field = widget.initialValue;
    }
  }

  /// The current table schema.
  TableSchema? _table;

  /// The current column field.
  SchemaField? _field;

  @override
  Widget build(BuildContext context) {
    if (_field != null) {
      _table = _field!.schema;
    }

    List<DropdownMenuItem<TableSchema>> tableEntries = [];
    List<DropdownMenuItem<SchemaField>> columnEntries = [];

    // We don't allow the user to select from the CCD tables because the DataIds of visits/exposures
    // are the same for all detectors, which means they cannot be properly searched.
    tableEntries = widget.databaseSchema.tables.entries
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
        .where((e) => (!kCcdTables.contains(e.value!.name)))
        .toList();

    if (_table != null) {
      columnEntries =
          _table!.fields.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<TableSchema>(
          decoration: const InputDecoration(
            labelText: "Table",
            border: OutlineInputBorder(),
          ),
          value: _table,
          items: tableEntries,
          onChanged: (TableSchema? newTable) {
            setState(() {
              _table = newTable;
              _field = _table!.fields.values.first;
            });
            widget.onChanged(_field);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<SchemaField>(
          decoration: const InputDecoration(
            labelText: "Column",
            border: OutlineInputBorder(),
          ),
          value: _field,
          items: columnEntries,
          onChanged: (SchemaField? newField) {
            setState(() {
              newField ??= _table!.fields.values.first;
              _field = newField;
            });
            widget.onChanged(newField);
          },
        ),
      ],
    );
  }
}
