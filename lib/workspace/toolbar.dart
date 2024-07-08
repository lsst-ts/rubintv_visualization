import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/editors/query.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class ToolbarAction extends WorkspaceEvent {
  ToolbarAction();
}

class DatePickerWidget extends StatefulWidget {
  final DateTime? dayObs;
  const DatePickerWidget({
    super.key,
    required this.dayObs,
  });

  @override
  DatePickerWidgetState createState() => DatePickerWidgetState();
}

class DatePickerWidgetState extends State<DatePickerWidget> {
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
        GestureDetector(
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
        ),
        ElevatedButton(
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
        ),
      ],
    );
  }
}

class Toolbar extends StatefulWidget {
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
          MenuAnchor(
            builder: (BuildContext context, MenuController controller, Widget? child) {
              return IconButton(
                icon: const Icon(Icons.menu),
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
          const SizedBox(width: 10),
          Center(
              child: Container(
            margin: const EdgeInsets.only(left: 4),
            height: 10,
            width: 10,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getStatusIndicator(webSocketManager.isConnected, workspace.instrument != null),
            ),
          )),
          const SizedBox(width: 30),
          DropdownButton<String?>(
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
              if (value != null) {
                webSocketManager.sendMessage(LoadInstrumentAction(instrument: value).toJson());
              }
            },
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: workspace.instrument == null && !workspace.isShowingFocalPlane
                ? null
                : () {
                    context.read<WorkspaceBloc>().add(ShowFocalPlaneEvent());
                  },
            icon: const Icon(Icons.lens_blur),
          ),
          Text(workspace.detector?.name == null
              ? 'No detector selected'
              : "${workspace.detector!.id}: ${workspace.detector!.name}"),
          const Spacer(),
          IconButton(
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
          ),
          IconButton(
            icon:
                Icon(Icons.travel_explore, color: workspace.globalQuery == null ? Colors.grey : Colors.green),
            onPressed: () {
              WorkspaceBloc bloc = context.read<WorkspaceBloc>();
              showDialog(
                  context: context,
                  builder: (BuildContext context) => Dialog(
                        child: QueryEditor(
                          theme: workspace.theme,
                          expression: QueryExpression(
                            queries: workspace.globalQuery == null ? [] : [workspace.globalQuery!],
                          ),
                          onCompleted: (Query? query) {
                            bloc.add(UpdateGlobalQueryEvent(globalQuery: query));
                          },
                        ),
                      ));
            },
          ),
          SizedBox(
            height: workspace.theme.toolbarHeight,
            child: DatePickerWidget(
              dayObs: workspace.dayObs,
            ),
          ),
        ],
      ),
    );
  }
}
