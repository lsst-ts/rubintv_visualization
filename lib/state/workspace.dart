import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:rubintv_visualization/chart.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/time_machine.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/menu.dart';
import 'package:rubintv_visualization/workspace/toolbar.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// Auto counter to keep track of the next window ID.
int _nextWindowId = 0;

/// Tools for selecting unique sources.
enum MultiSelectionTool {
  zoom(Icons.zoom_in),
  select(Icons.touch_app),
  drill(Icons.query_stats),
  pan(Icons.pan_tool);

  final IconData icon;
  const MultiSelectionTool(this.icon);
}

/// The full working area of the app.
class Workspace {
  /// Windows to display in the [Workspace].
  final Map<int, Window> _windows;

  /// The theme for the app
  final ChartTheme theme;

  /// Keys for selected data points.
  /// The key is name of the [Database] containing the point, and the [Set] is the
  /// set of keys in that [Database] that are selected.
  final Map<String, Set<dynamic>> _selected;

  /// Which tool to use for multi-selection/zoom
  final MultiSelectionTool multiSelectionTool;

  // The websocket connection to the analysis service.
  final WebSocket? webSocket;

  const Workspace({
    required this.theme,
    Map<int, Window> windows = const {},
    Map<String, Set<dynamic>> selected = const {},
    this.multiSelectionTool = MultiSelectionTool.select,
    this.webSocket,
  })  : _windows = windows,
        _selected = selected;

  Workspace copyWith({
    ChartTheme? theme,
    Map<int, Window>? windows,
    Map<String, Set<dynamic>>? selected,
    MultiSelectionTool? multiSelectionTool,
    WebSocket? webSocket,
  }) =>
      Workspace(
        theme: theme ?? this.theme,
        windows: windows ?? this.windows,
        selected: selected ?? this.selected,
        multiSelectionTool: multiSelectionTool ?? this.multiSelectionTool,
        webSocket: webSocket ?? this.webSocket,
      );

  /// Protect [_windows] so that it can only be updated through the app.
  Map<int, Window> get windows => {..._windows};

  /// Protect [_selected] so that it can only be updated through the app.
  Map<String, Set<dynamic>> get selected => {..._selected};

  /// Add a new [Window] to the [WorkspaceWidgetState].
  /// Normally the [index] is already created, unless
  /// the workspace is being loaded from disk.
  Workspace addWindow(Window window) {
    Map<int, Window> newWindows = {..._windows};

    if (window.id < 0) {
      // Use the next entry counter to increment the index
      int index = _nextWindowId++;
      window = window.copyWith(id: index);
    } else if (window.id > _nextWindowId) {
      // The new entry is greater than the next entry counter, so make the new next entry
      // greater than the current index
      _nextWindowId = window.id + 1;
    }
    newWindows[window.id] = window;

    return copyWith(
      windows: newWindows,
    );
  }
}

/// Process a message received from the analysis service.
class WebSocketReceiveMessageAction extends UiAction {
  final DataCenter dataCenter;
  final String message;

  const WebSocketReceiveMessageAction({
    required this.dataCenter,
    required this.message,
  });
}

/// Store the websocket connection to the analysis service.
TimeMachine<Workspace> webSocketReceiveMessageReducer(
  TimeMachine<Workspace> state,
  WebSocketReceiveMessageAction action,
) {
  Map<String, dynamic> message = jsonDecode(action.message);
  if (message["type"]! == "database schema") {
    action.dataCenter.addDatabase(message["content"]);
  }
  return state;
}

/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> updateWindowReducer(
  TimeMachine<Workspace> state,
  ApplyWindowUpdate action,
) {
  Workspace workspace = state.currentState;
  Map<int, Window> windows = {...workspace.windows};
  Window window = windows[action.windowId]!
      .copyWith(offset: action.offset, size: action.size);
  windows[window.id] = window;
  workspace = workspace.copyWith(windows: windows);

  return state.updated(TimeMachineUpdate(
    comment: "update a window size and position",
    state: workspace,
  ));
}

/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> newScatterChartReducer(
  TimeMachine<Workspace> state,
  NewScatterChartAction action,
) {
  Workspace workspace = state.currentState;
  Offset offset = workspace.theme.newWindowOffset;

  if (workspace.windows.isNotEmpty) {
    // Shift from last window
    offset += workspace.windows.values.last.offset;
  }

  int id = -1;
  for (int key in workspace.windows.keys) {
    if (key > id) {
      id = key;
    }
  }

  workspace = workspace.addWindow(ScatterChart(
    id: ++id, offset: offset, size: workspace.theme.newPlotSize, data: {},
    //series: {},
    //axes: [null, null],
    //legend: ChartLegend(location: ChartLegendLocation.right),
  ));

  return state.updated(TimeMachineUpdate(
    comment: "add new Cartesian plot",
    state: workspace,
  ));
}

/// Reduce a [TimeMachineAction] and (potentially) update the history and workspace.
TimeMachine<Workspace> timeMachineReducer(
    TimeMachine<Workspace> state, TimeMachineAction action) {
  if (action.action == TimeMachineActions.first) {
    return state.first;
  } else if (action.action == TimeMachineActions.previous) {
    return state.previous;
  } else if (action.action == TimeMachineActions.next) {
    return state.next;
  } else if (action.action == TimeMachineActions.last) {
    return state.last;
  }
  return state;
}

/// Handle a workspace action
Reducer<TimeMachine<Workspace>> workspaceReducer =
    combineReducers<TimeMachine<Workspace>>([
  TypedReducer<TimeMachine<Workspace>, TimeMachineAction>(timeMachineReducer),
  TypedReducer<TimeMachine<Workspace>, ApplyWindowUpdate>(updateWindowReducer),
  TypedReducer<TimeMachine<Workspace>, WebSocketReceiveMessageAction>(
      webSocketReceiveMessageReducer),
  TypedReducer<TimeMachine<Workspace>, NewScatterChartAction>(
      newScatterChartReducer),
  /*TypedReducer<TimeMachine<Workspace>, SeriesUpdateAction>(updateSeriesReducer),
  TypedReducer<TimeMachine<Workspace>, AxisUpdate>(updateAxisReducer),
  TypedReducer<TimeMachine<Workspace>, RectSelectionAction>(
      rectSelectionReducer),
  TypedReducer<TimeMachine<Workspace>, PointSelectionAction>(
      pointSelectionReducer),
  TypedReducer<TimeMachine<Workspace>, RectZoomAction>(rectZoomReducer),
  TypedReducer<TimeMachine<Workspace>, RemoveChartAction>(removeChartReducer),
  TypedReducer<TimeMachine<Workspace>, UpdateMultiSelect>(
      updateMultiSelectReducer),*/
]);

/// A [Widget] used to display a set of re-sizable and translatable [Window] widgets in a container.
class WorkspaceViewer extends StatefulWidget {
  final Size size;
  final Workspace workspace;
  final DataCenter dataCenter;
  final DispatchAction dispatch;
  final bool isConnected;

  const WorkspaceViewer({
    super.key,
    required this.size,
    required this.workspace,
    required this.dataCenter,
    required this.dispatch,
    required this.isConnected,
  });

  @override
  WorkspaceViewerState createState() => WorkspaceViewerState();

  /// Implement the [WorkspaceViewer.of] method to allow children
  /// to find this container based on their [BuildContext].
  static WorkspaceViewerState of(BuildContext context) {
    final WorkspaceViewerState? result =
        context.findAncestorStateOfType<WorkspaceViewerState>();
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'WorkspaceViewer.of() called with a context that does not '
              'contain a WorkspaceViewer.'),
          ErrorDescription(
              'No WorkspaceViewer ancestor could be found starting from the context '
              'that was passed to WorkspaceViewer.of().'),
          ErrorHint(
              'This probably happened when an interactive child was created '
              'outside of an WorkspaceViewer'),
          context.describeElement('The context used was')
        ]);
      }
      return true;
    }());
    return result!;
  }
}

class WorkspaceViewerState extends State<WorkspaceViewer> {
  ChartTheme get theme => widget.workspace.theme;
  Size get size => widget.size;
  Workspace get info => widget.workspace;
  DataCenter get dataCenter => widget.dataCenter;
  DispatchAction get dispatch => widget.dispatch;
  Map<String, Set<dynamic>> get selected => widget.workspace.selected;

  WindowInteractionInfo? interactionInfo;

  @override
  Widget build(BuildContext context) {
    return AppMenu(
      theme: theme,
      dispatch: dispatch,
      dataCenter: dataCenter,
      child: Column(children: [
        Toolbar(
          tool: widget.workspace.multiSelectionTool,
          isConnected: widget.isConnected,
        ),
        SizedBox(
          width: size.width,
          height: size.height - 2 * kToolbarHeight,
          child: Builder(
            builder: (BuildContext context) {
              List<Widget> children = [];
              for (Window window in info.windows.values) {
                Offset offset = window.offset;
                Size size = window.size;
                if (interactionInfo != null &&
                    window.id == interactionInfo!.id) {
                  offset = interactionInfo!.offset;
                  size = interactionInfo!.size;
                }

                children.add(Positioned(
                  left: offset.dx,
                  top: offset.dy,
                  child: ResizableWindow(
                    info: window,
                    theme: theme,
                    title: window.title,
                    dispatch: _updateWindow,
                    size: size,
                    toolbar: window.createToolbar(context),
                    child: window.createWidget(context),
                  ),
                ));
              }

              return Stack(
                children: children,
              );
            },
          ),
        ),
      ]),
    );
  }

  void _updateWindow(WindowUpdate update) {
    // Translation updates
    if (update is StartDragWindowUpdate) {
      return startWindowDrag(update);
    }
    if (update is UpdateDragWindowUpdate) {
      return updateWindowDrag(update);
    }
    if (update is WindowDragEnd) {
      return dragEnd();
    }
    // Resize updates
    if (update is StartWindowResize) {
      return startWindowResize(update);
    }
    if (update is UpdateWindowResize) {
      return updateWindowReSize(update);
    }
    if (update is EndWindowResize) {
      return dragEnd();
    }
    throw ArgumentError("Unrecognized WindowUpdate $update");
  }

  /// Keep track of the starting drag position
  void startWindowDrag(StartDragWindowUpdate update) {
    if (interactionInfo != null) {
      dragEnd();
    }
    Window window = info.windows[update.windowId]!;
    interactionInfo = WindowDragInfo(
      id: update.windowId,
      pointerOffset: window.offset - update.details.localPosition,
      offset: window.offset,
      size: window.size,
    );
    setState(() {});
  }

  void updateWindowDrag(UpdateDragWindowUpdate update) {
    if (interactionInfo is! WindowDragInfo) {
      dragEnd();
      throw Exception("Mismatched interactionInfo, got $interactionInfo");
    }
    setState(() {
      WindowDragInfo interaction = interactionInfo as WindowDragInfo;
      interaction.offset = update.details.localPosition +
          (interactionInfo as WindowDragInfo).pointerOffset;
    });
  }

  void dragEnd() {
    if (interactionInfo != null) {
      dispatch(ApplyWindowUpdate(
        windowId: interactionInfo!.id,
        offset: interactionInfo!.offset,
        size: interactionInfo!.size,
      ));
      interactionInfo = null;
      setState(() {});
    }
  }

  void startWindowResize(StartWindowResize update) {
    if (interactionInfo != null) {
      dragEnd();
    }
    Window window = info.windows[update.windowId]!;

    interactionInfo = WindowResizeInfo(
      id: update.windowId,
      initialPointerOffset: update.details.globalPosition,
      initialSize: window.size,
      initialOffset: window.offset,
      offset: window.offset,
      size: window.size,
    );
    setState(() {});
  }

  void updateWindowReSize(UpdateWindowResize update) {
    if (interactionInfo is! WindowResizeInfo) {
      dragEnd();
      throw Exception("Mismatched interactionInfo, got $interactionInfo");
    }
    WindowResizeInfo interaction = interactionInfo as WindowResizeInfo;
    Offset deltaPosition =
        update.details.globalPosition - interaction.initialPointerOffset;

    double left = interaction.initialOffset.dx;
    double top = interaction.initialOffset.dy;
    double width = interaction.initialSize.width;
    double height = interaction.initialSize.height;

    // Update the width and x-offset
    if (update.direction == WindowResizeDirections.right ||
        update.direction == WindowResizeDirections.downRight) {
      width = interaction.initialSize.width + deltaPosition.dx;
    } else if (update.direction == WindowResizeDirections.left ||
        update.direction == WindowResizeDirections.downLeft) {
      left = interaction.initialOffset.dx + deltaPosition.dx;
      width = interaction.initialSize.width - deltaPosition.dx;
    }

    // Update the height and y-offset
    if (update.direction == WindowResizeDirections.down ||
        update.direction == WindowResizeDirections.downLeft ||
        update.direction == WindowResizeDirections.downRight) {
      height = interaction.initialSize.height + deltaPosition.dy;
    }

    interaction.offset = Offset(left, top);
    interaction.size = Size(width, height);
    setState(() {});
  }
}
