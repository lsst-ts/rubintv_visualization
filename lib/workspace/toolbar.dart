import 'package:flutter/material.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/query/widget.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/workspace.dart';

class ToolbarAction extends UiAction {
  const ToolbarAction();
}

class UpdateMultiSelect extends ToolbarAction {
  final MultiSelectionTool tool;

  UpdateMultiSelect(this.tool);
}

class DatePickerWidget extends StatefulWidget {
  const DatePickerWidget({super.key, required this.dispatch});

  final DispatchAction dispatch;

  @override
  DatePickerWidgetState createState() => DatePickerWidgetState();
}

class DatePickerWidgetState extends State<DatePickerWidget> {
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    DateTime? date = selectedDate?.toLocal();
    String dateString = date != null
        ? "${date.year}-${date.month}-${date.day}"
        : 'No date selected';

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

            widget.dispatch(UpdateGlobalObsDateAction(obsDate: pickedDate));
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
              widget.dispatch(const UpdateGlobalObsDateAction(obsDate: null));
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
  final MultiSelectionTool tool;
  final bool isConnected;

  const Toolbar({
    super.key,
    required this.tool,
    required this.isConnected,
  });

  @override
  ToolbarState createState() => ToolbarState();
}

class ToolbarState extends State<Toolbar> {
  late MultiSelectionTool tool;

  @override
  void initState() {
    super.initState();
    tool = widget.tool;
  }

  @override
  Widget build(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);

    return Container(
      width: workspace.size.width,
      height: workspace.theme.toolbarHeight,
      decoration: BoxDecoration(
        color: workspace.theme.themeData.colorScheme.primaryContainer,
      ),
      child: Row(
        children: [
          Center(
              child: Container(
            margin: const EdgeInsets.only(left: 4),
            height: 10,
            width: 10,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle, // Makes the container a circle
              color: widget.isConnected
                  ? Colors.green
                  : Colors.red, // Fills the circle with blue color
            ),
          )),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.travel_explore,
                color: workspace.widget.workspace.globalQuery == null
                    ? Colors.grey
                    : Colors.green),
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (BuildContext context) => Dialog(
                        child: QueryEditor(
                          theme: workspace.theme,
                          expression: QueryExpression(
                            queries:
                                workspace.widget.workspace.globalQuery == null
                                    ? []
                                    : [workspace.widget.workspace.globalQuery!],
                            dataCenter: workspace.dataCenter,
                          ),
                          onCompleted: (Query? query) {
                            workspace.dispatch(
                                UpdateGlobalQueryAction(query: query));
                          },
                        ),
                      ));
            },
          ),
          SizedBox(
            height: workspace.theme.toolbarHeight,
            child: DatePickerWidget(dispatch: workspace.widget.dispatch),
          ),
          SegmentedButton<MultiSelectionTool>(
            selected: {tool},
            segments: [
              ButtonSegment(
                value: MultiSelectionTool.select,
                icon: Icon(Icons.touch_app,
                    color: workspace.theme.themeData.primaryColor),
              ),
              ButtonSegment(
                value: MultiSelectionTool.zoom,
                icon: Icon(Icons.zoom_in,
                    color: workspace.theme.themeData.primaryColor),
              ),
              ButtonSegment(
                value: MultiSelectionTool.drill,
                icon: Icon(Icons.query_stats,
                    color: workspace.theme.themeData.primaryColor),
              ),
              ButtonSegment(
                value: MultiSelectionTool.pan,
                icon: Icon(Icons.pan_tool,
                    color: workspace.theme.themeData.primaryColor),
              ),
            ],
            onSelectionChanged: (Set<MultiSelectionTool> selection) {
              tool = selection.first;
              workspace.dispatch(UpdateMultiSelect(selection.first));
            },
          ),
        ],
      ),
    );
  }
}
