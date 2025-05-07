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
                    message: "Accept",
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
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (BuildContext context, int index) {
                  AxisId axisId = initialValue.keys.toList()[index];
                  SchemaField? currentValue = formState.value![axisId];

                  return Container(
                    margin: const EdgeInsets.all(10),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: "axis $index",
                        border: const OutlineInputBorder(),
                      ),
                      child: ColumnEditor(
                        theme: theme,
                        initialValue: currentValue ??
                            databaseSchema.tables.values.first.fields.values.first, // Fallback to default
                        onChanged: (SchemaField? field) {
                          Map<AxisId, SchemaField?> fields = {...formState.value!};
                          fields[axisId] = field;
                          formState.didChange(fields);
                        },
                        databaseSchema: databaseSchema,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
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

  /// GlobalKey to access the RenderBox of the input field
  final GlobalKey _fieldKey = GlobalKey();

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

  bool _isInputValid = true;

  @override
  Widget build(BuildContext context) {
    if (_field != null) {
      _table = _field!.schema;
    }

    List<DropdownMenuItem<TableSchema>> tableEntries = [];

    // We don't allow the user to select from the CCD tables because the DataIds of visits/exposures
    // are the same for all detectors, which means they cannot be properly searched.
    tableEntries = widget.databaseSchema.tables.entries
        .map((e) => DropdownMenuItem(value: e.value, child: Text(e.key)))
        .where((e) => (!kCcdTables.contains(e.value!.name)))
        .toList();

    // Define the list of columns based on the selected table
    final List<SchemaField> allColumns = _table?.fields.values.toList() ?? <SchemaField>[];
    final List<String> columnNames = allColumns.map((field) => field.name).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 6),
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

        // Dropdown for Columns
        Autocomplete<String>(
          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController,
              FocusNode focusNode, VoidCallback onFieldSubmitted) {
            // Pre-populate text for re-editing
            if (textEditingController.text.isEmpty && _field != null) {
              textEditingController.text = _field!.name;
            }

            // Add listener to select all text when the field gains focus
            focusNode.addListener(() {
              if (focusNode.hasFocus) {
                textEditingController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: textEditingController.text.length,
                );
              }
              if (!focusNode.hasFocus) {
                // Validate the input when the field loses focus
                final isValid = columnNames.contains(textEditingController.text);
                setState(() {
                  _isInputValid = isValid; // Update the validation state
                });
              }
            });

            return TextField(
              key: _fieldKey, // Assign the GlobalKey to the TextField
              controller: textEditingController,
              focusNode: focusNode,
              onSubmitted: (_) {
                onFieldSubmitted(); // Notify Autocomplete about the submission
              },
              decoration: InputDecoration(
                labelText: "Column",
                border: OutlineInputBorder(
                  borderSide: BorderSide(
                    color:
                        _isInputValid ? Colors.grey : Colors.red, // Change border color based on validation
                  ),
                ),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                errorText: _isInputValid ? null : "Invalid column name", // Show error message if invalid
              ),
            );
          },
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return columnNames; // Show all column names if input is empty
            }
            return columnNames.where((String columnName) {
              return columnName.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          optionsViewBuilder:
              (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
            // Use the GlobalKey to get the width of the input field
            final RenderBox renderBox = _fieldKey.currentContext!.findRenderObject() as RenderBox;
            final double width = renderBox.size.width;

            // Create a ScrollController to manage scrolling
            final ScrollController scrollController = ScrollController();

            // Define the height of a single item
            const double itemHeight = 48.0;
            const int middleIndex = 2; // The index just above the middle of the viewport

            const maxvisibleItemsCount = 6; // Maximum number of items to show at a time
            int visibleItemCount = maxvisibleItemsCount;
            if (options.length < visibleItemCount) {
              visibleItemCount = options.length; // Adjust to show all items if less than 6
            }
            developer.log("Options length is ${options.length}", name: "debug");

            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: SizedBox(
                  width: width, // Match the width of the input field
                  height: itemHeight * visibleItemCount, // Limit the height to show 6 items at a time
                  child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                      int highlightedIndex = AutocompleteHighlightedOption.of(context);
                      int prevHighlightedIndex = highlightedIndex; // Track the previous highlighted index

                      return ListView.builder(
                        controller: scrollController, // Attach the ScrollController
                        padding: EdgeInsets.zero,
                        itemCount: options.length, // Show all options
                        itemBuilder: (BuildContext context, int index) {
                          final String option = options.elementAt(index);

                          // Scroll to the highlighted option only if necessary
                          if (highlightedIndex == index) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              // Get the RenderBox of the ListView
                              final RenderBox listViewRenderBox =
                                  scrollController.position.context.storageContext.findRenderObject()
                                      as RenderBox;

                              // Get the position of the ListView relative to the screen
                              final Offset listViewOffset = listViewRenderBox.localToGlobal(Offset.zero);

                              // Calculate the position of the item relative to the ListView
                              final double itemOffset = index * itemHeight;
                              final double viewportStart = listViewOffset.dy;
                              final double viewportEnd = viewportStart + listViewRenderBox.size.height;

                              // Calculate the middle of the viewport
                              final double middleOffset = viewportStart + (middleIndex * itemHeight);

                              // Scroll only if the highlighted option is beyond the middle or out of view
                              if (itemOffset < viewportStart || itemOffset + itemHeight > viewportEnd) {
                                double targetOffset;

                                // If the highlighted option is beyond the middle, scroll to keep it just above the middle
                                if (itemOffset > middleOffset) {
                                  targetOffset = itemOffset - (middleIndex * itemHeight);
                                } else {
                                  // Otherwise, scroll to bring it into view
                                  targetOffset = itemOffset;
                                }

                                // Ensure the target offset doesn't exceed the maximum scroll extent
                                targetOffset = targetOffset.clamp(
                                  0.0,
                                  scrollController.position.maxScrollExtent,
                                );

                                scrollController.animateTo(
                                  targetOffset,
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                );
                              }

                              // Handle circular scrolling
                              if (options.length > maxvisibleItemsCount) {
                                if (highlightedIndex == 0 && prevHighlightedIndex == options.length - 1) {
                                  // User moved from the bottom to the top
                                  setState(() {
                                    highlightedIndex = 0;
                                  });
                                  scrollController.jumpTo(0);
                                } else if (highlightedIndex == options.length - 1 &&
                                    prevHighlightedIndex == 0) {
                                  // User moved from the top to the bottom
                                  setState(() {
                                    highlightedIndex = options.length - 1;
                                  });
                                  scrollController.jumpTo(scrollController.position.maxScrollExtent);
                                }
                              }

                              // Update the previous highlighted index
                              prevHighlightedIndex = highlightedIndex;
                            });
                          }

                          return GestureDetector(
                            onTap: () {
                              onSelected(option);
                            },
                            child: Container(
                              color: (highlightedIndex == index)
                                  ? Colors.grey[300]
                                  : null, // Highlight focused item
                              child: ListTile(
                                title: Text(option),
                                onTap: () {
                                  onSelected(option);
                                },
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
          onSelected: (String selectedColumn) {
            setState(() {
              _field = allColumns.firstWhere((field) => field.name == selectedColumn);
              _isInputValid = true; // Mark input as valid when a valid option is selected
            });
            widget.onChanged(_field);
          },
        ),
      ],
    );
  }
}
