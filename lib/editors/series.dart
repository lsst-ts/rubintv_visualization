import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/editors/query.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';

typedef SeriesQueryCallback = void Function(Query? query);

class SeriesEditor extends StatefulWidget {
  final AppTheme theme;
  final SeriesInfo series;
  final bool isNew;
  final WorkspaceViewerState workspace;
  final ChartBloc chartBloc;
  final DatabaseSchema databaseSchema;

  const SeriesEditor({
    super.key,
    required this.theme,
    required this.series,
    required this.workspace,
    required this.chartBloc,
    required this.databaseSchema,
    this.isNew = false,
  });

  @override
  SeriesEditorState createState() => SeriesEditorState();
}

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

  void updateQuery(Query? query) {
    series = series.copyWith(query: query);
  }

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
                IconButton(
                  onPressed: () {
                    showDialog(
                        context: context,
                        builder: (BuildContext context) => Dialog(
                              child: QueryEditor(
                                theme: theme,
                                expression: QueryExpression(
                                  queries: series.query == null ? [] : [series.query!],
                                ),
                                onCompleted: updateQuery,
                              ),
                            ));
                  },
                  icon: const Icon(Icons.query_stats),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.cancel, color: Colors.red),
                ),
                IconButton(
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
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class ColumnEditorFormField extends FormField<Map<AxisId, SchemaField?>> {
  final AppTheme theme;
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

class ColumnEditor extends StatefulWidget {
  final AppTheme theme;
  final ValueChanged<SchemaField?> onChanged;
  final SchemaField initialValue;
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

  TableSchema? _table;
  SchemaField? _field;

  @override
  Widget build(BuildContext context) {
    if (_field != null) {
      _table = _field!.schema;
    }

    List<DropdownMenuItem<TableSchema>> tableEntries = [];
    List<DropdownMenuItem<SchemaField>> columnEntries = [];

    tableEntries = widget.databaseSchema.tables.entries
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
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
