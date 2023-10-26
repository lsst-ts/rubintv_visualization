import 'package:flutter/material.dart';
import 'package:rubintv_visualization/chart/chart.dart';
import 'package:rubintv_visualization/chart/marker.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/editors/query.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/workspace/data.dart';

class Series {
  final UniqueId id;
  final String name;
  final List<SchemaField> fields;
  final MarkerSettings? marker;
  final ErrorBarSettings? errorBarSettings;
  final Query? query;
  final Chart chart;

  Series({
    required this.id,
    required this.name,
    required this.fields,
    required this.chart,
    this.marker,
    this.errorBarSettings,
    this.query,
  });

  Series copyWith({
    UniqueId? id,
    String? name,
    List<SchemaField>? fields,
    Chart? chart,
    MarkerSettings? marker,
    ErrorBarSettings? errorBarSettings,
    Query? query,
  }) =>
      Series(
        id: id ?? this.id,
        name: name ?? this.name,
        fields: fields ?? this.fields,
        chart: chart ?? this.chart,
        marker: marker ?? this.marker,
        errorBarSettings: errorBarSettings ?? this.errorBarSettings,
        query: query ?? this.query,
      );

  Series copy() => copyWith();

  @override
  String toString() => "Series<$id:name>";
}

/// Notify the [WorkspaceViewer] that the series has been updated
class SeriesUpdateAction extends UiAction {
  final Series series;
  final DataCenter dataCenter;
  final SchemaField? groupByColumn;

  const SeriesUpdateAction({
    required this.series,
    required this.dataCenter,
    this.groupByColumn,
  });
}

typedef SeriesQueryCallback = void Function(Query? query);

class SeriesEditor extends StatefulWidget {
  final AppTheme theme;
  final Series series;
  final bool isNew;
  final DataCenter dataCenter;
  final DispatchAction dispatch;

  const SeriesEditor({
    super.key,
    required this.theme,
    required this.series,
    required this.dataCenter,
    required this.dispatch,
    this.isNew = false,
  });

  @override
  SeriesEditorState createState() => SeriesEditorState();
}

class SeriesEditorState extends State<SeriesEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  AppTheme get theme => widget.theme;
  late Series series;

  /// [TextEditingController] for the series name.
  TextEditingController nameController = TextEditingController();

  /// Create a collection of [Series] based on unique values of the [groupName] column.
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
    List<SchemaField> fields = [...series.fields];
    fields[index] = column!;
    series = series.copyWith(fields: fields);
  }

  @override
  Widget build(BuildContext context) {
    print("Series is $series");
    DataCenter dataCenter = widget.dataCenter;

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 400,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  dataCenter: dataCenter,
                  initialValue: series.fields,
                  onSaved: (List<SchemaField?>? fields) {
                    series = series.copyWith(
                        fields: fields!.map((e) => e!).toList());
                  },
                  validator: (List<SchemaField?>? fields) {
                    if (fields == null || fields.any((e) => e == null)) {
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
                                      queries: series.query == null
                                          ? []
                                          : [series.query!],
                                      dataCenter: dataCenter,
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
                          widget.dispatch(SeriesUpdateAction(
                            series: series,
                            groupByColumn: groupByColumn,
                            dataCenter: dataCenter,
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

class ColumnEditorFormField extends FormField<List<SchemaField?>> {
  final AppTheme theme;
  final DataCenter dataCenter;

  ColumnEditorFormField({
    super.key,
    required this.theme,
    required this.dataCenter,
    required FormFieldSetter<List<SchemaField?>> onSaved,
    required FormFieldValidator<List<SchemaField?>> validator,
    required List<SchemaField?> initialValue,
    bool autovalidate = false,
  }) : super(
            onSaved: onSaved,
            validator: validator,
            initialValue: initialValue,
            builder: (FormFieldState<List<SchemaField?>> formState) {
              return Container(
                child: ListView.builder(
                  itemCount: initialValue.length,
                  shrinkWrap: true,
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                        margin: const EdgeInsets.all(10),
                        child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: "axis $index",
                              border: const OutlineInputBorder(),
                            ),
                            child: ColumnEditor(
                              theme: theme,
                              dataCenter: dataCenter,
                              initialValue: initialValue[index],
                              onChanged: (SchemaField? field) {
                                List<SchemaField?> fields = [
                                  ...formState.value!
                                ];
                                fields[index] = field;
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
  final DataCenter dataCenter;
  final ValueChanged<SchemaField?> onChanged;
  final SchemaField? initialValue;

  const ColumnEditor({
    super.key,
    required this.theme,
    required this.dataCenter,
    required this.onChanged,
    required this.initialValue,
  });

  @override
  ColumnEditorState createState() => ColumnEditorState();
}

class ColumnEditorState extends State<ColumnEditor> {
  AppTheme get theme => widget.theme;
  DataCenter get dataCenter => widget.dataCenter;

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

  Database? _database;
  Schema? _table;
  SchemaField? _field;

  @override
  Widget build(BuildContext context) {
    if (_field != null) {
      _table = _field!.schema;
      _database = _table!.database;
    }

    List<DropdownMenuItem<Database>> databaseEntries = dataCenter
        .databases.entries
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
        .toList();

    List<DropdownMenuItem<Schema>> tableEntries = [];
    List<DropdownMenuItem<SchemaField>> columnEntries = [];

    if (_database != null) {
      tableEntries = _database!.tables.entries
          .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
          .toList();
    }

    if (_table != null) {
      columnEntries = _table!.fields.values
          .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
          .toList();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<Database>(
          decoration: const InputDecoration(
            labelText: "Database",
            border: OutlineInputBorder(),
          ),
          value: _database,
          items: databaseEntries,
          onChanged: (Database? newDatabase) {
            setState(() {
              _database = newDatabase;
              _table = _database!.tables.values.first;
              _field = _table!.fields.values.first;
            });
            widget.onChanged(_field);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<Schema>(
          decoration: const InputDecoration(
            labelText: "Table",
            border: OutlineInputBorder(),
          ),
          value: _table,
          items: tableEntries,
          onChanged: (Schema? newTable) {
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
