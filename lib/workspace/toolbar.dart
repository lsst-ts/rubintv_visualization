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
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/dialog/widget.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/bloc.dart';
import 'package:rubintv_visualization/query/primitives.dart';
import 'package:rubintv_visualization/query/widget.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// A [Widget] used to display a toolbar at the top of the workspace.
class DatePickerWidget extends StatefulWidget {
  /// The date to display in the date picker.
  final DateTime? dayObs;

  const DatePickerWidget({
    super.key,
    required this.dayObs,
  });

  @override
  DatePickerWidgetState createState() => DatePickerWidgetState();
}

/// A [State] object for the [DatePickerWidget].
class DatePickerWidgetState extends State<DatePickerWidget> {
  /// The currently selected date.
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.dayObs;
  }

  @override
  void didUpdateWidget(DatePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    selectedDate = widget.dayObs;
  }

  @override
  Widget build(BuildContext context) {
    DateTime? date = selectedDate?.toLocal();
    String dateString = date != null ? "${date.year}-${date.month}-${date.day}" : 'No date selected';
    WorkspaceBloc workspaceBloc = context.read<WorkspaceBloc>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Tooltip(
            message: "Set day_obs",
            child: GestureDetector(
              onTap: () async {
                final DateTime? pickedDate = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2101),
                );

                workspaceBloc.add(UpdateGlobalObsDateEvent(dayObs: pickedDate));
              },
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.all(4),
                height: 40,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(dateString)),
              ),
            )),
        Tooltip(
            message: "Clear day_obs",
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedDate = null;
                  context.read<WorkspaceBloc>().add(UpdateGlobalObsDateEvent(dayObs: null));
                });
              },
              child: const Icon(
                Icons.clear,
                color: Colors.red,
              ),
            )),
      ],
    );
  }
}

/// A [Widget] used to display the toolbar at the top of the workspace.
class Toolbar extends StatefulWidget {
  /// The [WorkspaceState] object to use for the toolbar.
  final WorkspaceState workspace;

  const Toolbar({super.key, required this.workspace});

  @override
  ToolbarState createState() => ToolbarState();
}

/// Returns the color of the status indicator based on the connection status and whether an instrument is available.
Color _getStatusIndicator(bool isConnected, bool hasInstrument) {
  if (!isConnected) {
    return Colors.red;
  } else if (!hasInstrument) {
    return Colors.yellow;
  } else {
    return Colors.green;
  }
}

/// Display a dialog to load a workspace from a JSON string.
void _loadWorkspace(BuildContext context, WorkspaceBloc bloc) {
  final TextEditingController textFieldController = TextEditingController();

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Enter workspace JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: textFieldController,
            maxLines: null,
            minLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: "Enter workspace JSON here",
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('CANCEL'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          TextButton(
            child: const Text('LOAD'),
            onPressed: () {
              // Load the workspace from the text field
              String text = textFieldController.text;
              bloc.add(LoadWorkspaceFromTextEvent(text));
              // Add your custom action here
              Navigator.pop(context);
            },
          ),
        ],
      );
    },
  );
}

/// The [State] of the [Toolbar] widget.
class ToolbarState extends State<Toolbar> {
  WorkspaceState get workspace => widget.workspace;

  @override
  Widget build(BuildContext context) {
    WebSocketManager webSocketManager = WebSocketManager();
    WorkspaceViewerState workspaceViewer = WorkspaceViewer.of(context);

    return Container(
      width: workspaceViewer.size.width,
      height: workspace.theme.toolbarHeight,
      decoration: BoxDecoration(
        color: workspace.theme.themeData.colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          const SizedBox(width: 10),
          Tooltip(
              message: "Status Indicator",
              child: Center(
                  child: Container(
                margin: const EdgeInsets.only(left: 4),
                height: 10,
                width: 10,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusIndicator(webSocketManager.isConnected, workspace.instrument != null),
                ),
              ))),
          const SizedBox(width: 30),
          Tooltip(
              message: "Change current instrument",
              child: DropdownButton<String?>(
                value: workspace.instrument?.name,
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text("Select Instrument"),
                  ),
                  DropdownMenuItem(
                    value: "LsstCam",
                    child: Text("LSSTCam"),
                  ),
                  DropdownMenuItem(
                    value: "LsstComCam",
                    child: Text("LsstComCam"),
                  ),
                  DropdownMenuItem(
                    value: "Latiss",
                    child: Text("Latiss"),
                  ),
                  DropdownMenuItem(
                    value: "LsstComCamSim",
                    child: Text("LsstComCamSim"),
                  ),
                ],
                onChanged: (String? value) {
                  if (value == null || workspace.instrument?.name == value) {
                    return;
                  }
                  if (workspace.instrument != null && workspace.windows.isNotEmpty) {
                    // Show dialog to confirm changing instrument
                    // that lets the user know that the current workspace will be cleared
                    WorkspaceBloc bloc = context.read<WorkspaceBloc>();
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return changeInstrumentDialog(context, bloc, webSocketManager, value);
                      },
                    );
                  } else {
                    webSocketManager.sendMessage(LoadInstrumentAction(instrument: value).toJson());
                  }
                },
              )),
          const SizedBox(width: 10),
          Tooltip(
            message: "Show Focal Plane",
            child: IconButton(
              onPressed: workspace.instrument == null && !workspace.isShowingFocalPlane
                  ? null
                  : () {
                      context.read<WorkspaceBloc>().add(ShowFocalPlaneEvent());
                    },
              icon: const Icon(Icons.lens_blur),
            ),
          ),
          Tooltip(
            message: "Detector number and name",
            child: Text(workspace.detector?.name == null
                ? 'No detector selected'
                : "${workspace.detector!.id}: ${workspace.detector!.name}"),
          ),
          const Spacer(),
          Tooltip(
            message: "Load workspace",
            child: MenuAnchor(
              builder: (BuildContext context, MenuController controller, Widget? child) {
                return IconButton(
                  icon: const Icon(Icons.folder_open, color: Colors.green),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
              menuChildren: [
                MenuItemButton(
                  onPressed: () {
                    _loadWorkspace(context, context.read<WorkspaceBloc>());
                  },
                  child: const Text("From text"),
                ),
                MenuItemButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) => const Dialog(
                        child: FileDialogWidget(
                          action: FileDialogAction.load,
                        ),
                      ),
                    );
                  },
                  child: const Text("From file"),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: "Save workspace",
            child: MenuAnchor(
              builder: (BuildContext context, MenuController controller, Widget? child) {
                return IconButton(
                  icon: Icon(Icons.save,
                      color: workspace.instrument == null && !workspace.isShowingFocalPlane
                          ? Colors.grey[500]
                          : Colors.green),
                  onPressed: () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                );
              },
              menuChildren: [
                MenuItemButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: jsonEncode(workspace.toJson())));
                  },
                  child: const Text("Copy to clipboard"),
                ),
                MenuItemButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) => Dialog(
                        child: FileDialogWidget(
                          action: FileDialogAction.save,
                          content: jsonEncode(workspace.toJson()),
                        ),
                      ),
                    );
                  },
                  child: const Text("Save to file"),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: "Add a chart to the workspace",
            child: MenuAnchor(
              builder: (BuildContext context, MenuController controller, Widget? child) {
                return IconButton(
                  icon: Icon(Icons.add_chart,
                      color: workspace.instrument == null && !workspace.isShowingFocalPlane
                          ? Colors.grey[500]
                          : Colors.green),
                  onPressed: workspace.instrument == null && !workspace.isShowingFocalPlane
                      ? null
                      : () {
                          if (controller.isOpen) {
                            controller.close();
                          } else {
                            controller.open();
                          }
                        },
                );
              },
              menuChildren: [
                MenuItemButton(
                  onPressed: () {
                    context.read<WorkspaceBloc>().add(CreateNewWindowEvent(
                          windowType: WindowTypes.cartesianScatter,
                        ));
                  },
                  child: const Text("New Cartesian Scatter Plot"),
                ),
                MenuItemButton(
                  onPressed: () {
                    context.read<WorkspaceBloc>().add(CreateNewWindowEvent(
                          windowType: WindowTypes.polarScatter,
                        ));
                  },
                  child: const Text("New Polar Scatter Plot"),
                ),
                MenuItemButton(
                  onPressed: () {
                    context.read<WorkspaceBloc>().add(CreateNewWindowEvent(
                          windowType: WindowTypes.histogram,
                        ));
                  },
                  child: const Text("New Histogram"),
                ),
                MenuItemButton(
                  onPressed: () {
                    context.read<WorkspaceBloc>().add(CreateNewWindowEvent(
                          windowType: WindowTypes.box,
                        ));
                  },
                  child: const Text("New Box Chart"),
                ),
                MenuItemButton(
                  onPressed: () {
                    context.read<WorkspaceBloc>().add(CreateNewWindowEvent(
                          windowType: WindowTypes.focalPlane,
                        ));
                  },
                  child: const Text("New Focal Plane Chart"),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
              message: "Copy",
              child: IconButton(
                icon: const Icon(Icons.copy, color: Colors.green),
                onPressed: () async {
                  String result;
                  SelectionController selectionController = ControlCenter().selectionController;
                  SelectionController drillDownController = ControlCenter().drillDownController;
                  List<Object> dataPoints = selectionController.selectedDataPoints.toList();
                  if (dataPoints.isEmpty) {
                    dataPoints = drillDownController.selectedDataPoints.toList();
                  }
                  if (dataPoints.isEmpty) {
                    result = "";
                  } else {
                    result = dataPoints.map((e) {
                      DataId dataId = e as DataId;
                      return "(${dataId.dayObs}, ${dataId.seqNum})";
                    }).join(',');
                  }

                  if (result.isNotEmpty) {
                    result = "[$result]";
                  }

                  await Clipboard.setData(ClipboardData(text: result));
                },
              )),
          Tooltip(
              message: "Change global query",
              child: IconButton(
                icon: Icon(Icons.travel_explore,
                    color: workspace.globalQuery == null ? Colors.grey : Colors.green),
                onPressed: () {
                  WorkspaceBloc bloc = context.read<WorkspaceBloc>();
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return Dialog(
                          child: BlocProvider(
                            create: (context) => QueryBloc(workspace.globalQuery),
                            child: QueryEditor(
                              theme: workspace.theme,
                              onCompleted: (QueryExpression? query) {
                                bloc.add(UpdateGlobalQueryEvent(globalQuery: query));
                              },
                              database: DataCenter().databases[workspace.instrument!.schema]!,
                            ),
                          ),
                        );
                      });
                },
              )),
          SizedBox(
            height: workspace.theme.toolbarHeight,
            child: DatePickerWidget(
              dayObs: workspace.dayObs,
            ),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: "Clear all selections",
            child: IconButton(
              icon: const Icon(Icons.clear_all, color: Colors.red),
              onPressed: () {
                context.read<WorkspaceBloc>().add(ClearWorkspaceEvent());
              },
            ),
          ),
        ],
      ),
    );
  }

  AlertDialog changeInstrumentDialog(
      BuildContext context, WorkspaceBloc bloc, WebSocketManager webSocketManager, String value) {
    return AlertDialog(
      title: const Text("Change Instrument"),
      content: const Text("Changing the instrument will clear the current workspace."),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("CANCEL"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            bloc.add(ClearWorkspaceEvent());
            webSocketManager.sendMessage(LoadInstrumentAction(instrument: value).toJson());
          },
          child: const Text("CHANGE"),
        ),
      ],
    );
  }
}
