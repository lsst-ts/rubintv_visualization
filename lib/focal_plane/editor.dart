import 'package:flutter/material.dart';
import 'package:rubintv_visualization/focal_plane/chart.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';

class FocalPlaneColumnEditor extends StatefulWidget {
  final AppTheme theme;
  final SchemaField initialValue;
  final DatabaseSchema databaseSchema;
  final FocalPlaneChartBloc chartBloc;
  final WorkspaceViewerState workspace;

  const FocalPlaneColumnEditor({
    super.key,
    required this.theme,
    required this.initialValue,
    required this.databaseSchema,
    required this.chartBloc,
    required this.workspace,
  });

  @override
  FocalPlaneColumnEditorState createState() => FocalPlaneColumnEditorState();
}

class FocalPlaneColumnEditorState extends State<FocalPlaneColumnEditor> {
  late SchemaField _field;

  @override
  void initState() {
    super.initState();
    _field = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<TableSchema>> tableEntries = widget.databaseSchema.tables.entries
        .where((e) => kCcdTables.contains(e.key))
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
        .toList();

    List<DropdownMenuItem<SchemaField>> columnEntries =
        _field.schema.fields.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<TableSchema>(
              decoration: const InputDecoration(
                labelText: "Table",
                border: OutlineInputBorder(),
              ),
              value: _field.schema,
              items: tableEntries,
              onChanged: (TableSchema? newTable) {
                setState(() {
                  if (newTable != null) {
                    _field = newTable.fields.values.first;
                  }
                });
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
                  if (newField != null) {
                    _field = newField;
                  }
                });
              },
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.cancel, color: Colors.red),
                ),
                IconButton(
                  onPressed: () {
                    widget.chartBloc.add(FocalPlaneUpdateColumnEvent(
                      field: _field,
                      dayObs: getFormattedDate(widget.workspace.info!.dayObs),
                      selected: ControlCenter()
                          .selectionController
                          .selectedDataPoints
                          .map((e) => e as DataId)
                          .toSet(),
                    ));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
