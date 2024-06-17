import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/editors/query.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/series.dart';

typedef SeriesQueryCallback = void Function(Query? query);

class SeriesEditor extends StatefulWidget {
  final AppTheme theme;
  final SeriesInfo series;
  final bool isNew;
  final WorkspaceViewerState workspace;
  final ChartBloc chartBloc;

  const SeriesEditor({
    super.key,
    required this.theme,
    required this.series,
    required this.workspace,
    required this.chartBloc,
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
    //DataCenter dataCenter = widget.workspace.dataCenter;

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 400,
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
                        obsDate: getFormattedDate(widget.workspace.info!.obsDate),
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

  ColumnEditorFormField({
    super.key,
    required this.theme,
    required FormFieldSetter<Map<AxisId, SchemaField?>> onSaved,
    required FormFieldValidator<Map<AxisId, SchemaField?>> validator,
    required Map<AxisId, SchemaField?> initialValue,
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
                              initialValue: initialValue[index],
                              onChanged: (SchemaField? field) {
                                Map<AxisId, SchemaField?> fields = {...formState.value!};
                                fields[axisId] = field;
                                formState.didChange(fields);
                              },
                            )));
                  },
                ),
              );
            });
}

class ColumnEditor extends StatefulWidget {
  final AppTheme theme;
  final ValueChanged<SchemaField?> onChanged;
  final SchemaField? initialValue;

  const ColumnEditor({
    super.key,
    required this.theme,
    required this.onChanged,
    required this.initialValue,
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

  DatabaseSchema? _database;
  TableSchema? _table;
  SchemaField? _field;

  @override
  Widget build(BuildContext context) {
    if (_field != null) {
      _table = _field!.schema;
      _database = _table!.database;
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<DatabaseSchema>(
          decoration: const InputDecoration(
            labelText: "Database",
            border: OutlineInputBorder(),
          ),
          value: _database,
          items: databaseEntries,
          onChanged: (DatabaseSchema? newDatabase) {
            setState(() {
              _database = newDatabase;
              _table = _database!.tables.values.first;
              _field = _table!.fields.values.first;
            });
            widget.onChanged(_field);
          },
        ),
        const SizedBox(height: 10),
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
