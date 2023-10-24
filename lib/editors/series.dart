import 'package:flutter/material.dart';
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
  final MarkerSettings? marker;
  final ErrorBarSettings? errorBarSettings;
  final Query? query;

  Series({
    required this.id,
    required this.name,
    this.marker,
    this.errorBarSettings,
    this.query,
  });

  Series copyWith({
    UniqueId? id,
    String? name,
    MarkerSettings? marker,
    ErrorBarSettings? errorBarSettings,
    Query? query,
  }) =>
      Series(
        id: id ?? this.id,
        name: name ?? this.name,
        marker: marker ?? this.marker,
        errorBarSettings: errorBarSettings ?? this.errorBarSettings,
        query: query ?? this.query,
      );

  Series copy() => copyWith();
}

class SeriesData {
  final UniqueId seriesId;
  final Map<SchemaField, dynamic> data;

  const SeriesData({
    required this.seriesId,
    required this.data,
  });
}

/// Notify the [WorkspaceViewer] that the series has been updated
class SeriesUpdateAction extends UiAction {
  final Series series;
  final DataCenter dataCenter;
  final String? groupByColumn;

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
  String? groupByColumn;

  @override
  void initState() {
    super.initState();
    series = widget.series.copy();
    nameController.text = series.name;
  }

  void updateQuery(Query? query) {
    series = series.copyWith(query: query);
  }

  @override
  Widget build(BuildContext context) {
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
                ColumnEditor(theme: theme, dataCenter: dataCenter),
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

class ColumnEditor extends StatefulWidget {
  final AppTheme theme;
  final DataCenter dataCenter;

  const ColumnEditor({
    super.key,
    required this.theme,
    required this.dataCenter,
  });

  @override
  ColumnEditorState createState() => ColumnEditorState();
}

class ColumnEditorState extends State<ColumnEditor> {
  AppTheme get theme => widget.theme;
  DataCenter get dataCenter => widget.dataCenter;
  Database? _database;
  Schema? _table;
  SchemaField? _field;

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<Database>> databaseEntries = dataCenter
        .databases.entries
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
        .toList();

    _database ??= dataCenter.databases.values.first;

    final List<DropdownMenuItem<Schema>> tableEntries = _database!
        .tables.entries
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
        .toList();

    _table ??= _database!.tables.values.first;

    final List<DropdownMenuItem<SchemaField>> columnEntries = _table!
        .fields.values
        .map((e) => DropdownMenuItem(value: e, child: Text(e.name)))
        .toList();

    List<Widget> children = [
      DropdownButtonFormField(
        value: _database,
        items: databaseEntries,
        onChanged: (Database? database) {
          setState(() {
            _database = _database;
          });
        },
      ),
      DropdownButtonFormField(
        value: _table,
        items: tableEntries,
        onChanged: (Schema? table) {
          setState(() {
            _table = table;
          });
        },
      ),
      DropdownButtonFormField(
        value: _field,
        items: columnEntries,
        onChanged: (SchemaField? field) {
          setState(() {
            _field = field;
          });
        },
        validator: (SchemaField? value) {
          /*List<int>? mismatched =
              info.canAddSeries(series: series, dataCenter: dataCenter);
          if (mismatched == null) {
            return "Mismatch between columns and plot axes";
          }
          if (mismatched.contains(i)) {
            return "Column is not compatible with plot axes";
          }*/
          return null;
        },
      ),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
