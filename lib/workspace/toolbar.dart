import 'package:flutter/material.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/editors/query.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/time_machine.dart';
import 'package:rubintv_visualization/state/workspace.dart';

class ToolbarAction extends UiAction {
  const ToolbarAction();
}

class DatePickerWidget extends StatefulWidget {
  final DateTime? obsDate;
  const DatePickerWidget({
    super.key,
    required this.dispatch,
    required this.obsDate,
  });

  final DispatchAction dispatch;

  @override
  DatePickerWidgetState createState() => DatePickerWidgetState();
}

class DatePickerWidgetState extends State<DatePickerWidget> {
  DateTime? selectedDate;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.obsDate;
  }

  @override
  void didUpdateWidget(DatePickerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    selectedDate = widget.obsDate;
  }

  @override
  Widget build(BuildContext context) {
    DateTime? date = selectedDate?.toLocal();
    String dateString = date != null ? "${date.year}-${date.month}-${date.day}" : 'No date selected';

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
  final bool isConnected;
  final bool isFirstFrame;
  final bool isLastFrame;

  const Toolbar({
    super.key,
    required this.isConnected,
    required this.isFirstFrame,
    required this.isLastFrame,
  });

  @override
  ToolbarState createState() => ToolbarState();
}

class ToolbarState extends State<Toolbar> {
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
              color: widget.isConnected ? Colors.green : Colors.red, // Fills the circle with blue color
            ),
          )),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.undo, color: widget.isFirstFrame ? Colors.grey : Colors.green),
            onPressed: () {
              workspace.dispatch(const TimeMachineAction(action: TimeMachineActions.previous));
            },
          ),
          IconButton(
            icon: Icon(Icons.redo, color: widget.isLastFrame ? Colors.grey : Colors.green),
            onPressed: () {
              workspace.dispatch(const TimeMachineAction(action: TimeMachineActions.next));
            },
          ),
          IconButton(
            icon: Icon(Icons.travel_explore,
                color: workspace.widget.workspace.globalQuery == null ? Colors.grey : Colors.green),
            onPressed: () {
              showDialog(
                  context: context,
                  builder: (BuildContext context) => Dialog(
                        child: QueryEditor(
                          theme: workspace.theme,
                          expression: QueryExpression(
                            queries: workspace.widget.workspace.globalQuery == null
                                ? []
                                : [workspace.widget.workspace.globalQuery!],
                            dataCenter: workspace.dataCenter,
                          ),
                          onCompleted: (Query? query) {
                            workspace.dispatch(UpdateGlobalQueryAction(query: query));
                          },
                        ),
                      ));
            },
          ),
          SizedBox(
            height: workspace.theme.toolbarHeight,
            child: DatePickerWidget(
              dispatch: workspace.widget.dispatch,
              obsDate: workspace.widget.workspace.obsDate,
            ),
          ),
        ],
      ),
    );
  }
}
