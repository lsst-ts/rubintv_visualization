import 'package:flutter/material.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class ToolbarAction extends UiAction {
  const ToolbarAction();
}

class UpdateMultiSelect extends ToolbarAction {
  final MultiSelectionTool tool;

  UpdateMultiSelect(this.tool);
}

class DatePickerWidget extends StatefulWidget {
  const DatePickerWidget({super.key});

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
            if (pickedDate != null && pickedDate != selectedDate) {
              setState(() {
                selectedDate = pickedDate;
              });
            }
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

  const Toolbar({
    super.key,
    required this.tool,
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
          const Spacer(),
          SizedBox(
            height: workspace.theme.toolbarHeight,
            child: DatePickerWidget(),
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
