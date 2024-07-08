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
import 'package:rubintv_visualization/focal_plane/chart.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';

/// A [Widget] that allows the user to select a column from a table.
class FocalPlaneColumnEditor extends StatefulWidget {
  /// The [AppTheme] used to style the editor.
  final AppTheme theme;

  /// The initial value of the column.
  final SchemaField initialValue;

  /// The database schema used to populate the dropdowns.
  final DatabaseSchema databaseSchema;

  /// The [FocalPlaneChartBloc] used containing the chart.
  final FocalPlaneChartBloc chartBloc;

  /// The current workspace state.
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

/// The [State] of the [FocalPlaneColumnEditor].
class FocalPlaneColumnEditorState extends State<FocalPlaneColumnEditor> {
  /// The currently selected field.
  late SchemaField _field;

  @override
  void initState() {
    super.initState();
    _field = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    // Only allow the user to choose from CCD tables
    List<DropdownMenuItem<TableSchema>> tableEntries = widget.databaseSchema.tables.entries
        .where((e) => kCcdTables.contains(e.key))
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
        .toList();

    // Populate the column dropdown with the fields from the selected table
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
