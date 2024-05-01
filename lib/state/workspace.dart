import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/state/chart.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/time_machine.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/menu.dart';
import 'package:rubintv_visualization/workspace/series.dart';
import 'package:rubintv_visualization/workspace/toolbar.dart';
import 'package:rubintv_visualization/workspace/window.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  final Map<UniqueId, Window> _windows;

  /// The theme for the app
  final AppTheme theme;

  /// A query that applies to all plots (that opt in to gloabl queries)
  final Query? globalQuery;

  /// The observation date for any tables that have an observation date column.
  final DateTime? obsDate;

  /// Which tool to use for multi-selection/zoom
  final MultiSelectionTool multiSelectionTool;

  // The websocket connection to the analysis service.
  final WebSocketChannel? webSocket;

  const Workspace({
    required this.theme,
    Map<UniqueId, Window> windows = const {},
    this.multiSelectionTool = MultiSelectionTool.select,
    this.webSocket,
    this.globalQuery,
    this.obsDate,
  }) : _windows = windows;

  Workspace copyWith({
    AppTheme? theme,
    Map<UniqueId, Window>? windows,
    MultiSelectionTool? multiSelectionTool,
    WebSocketChannel? webSocket,
  }) =>
      Workspace(
        theme: theme ?? this.theme,
        windows: windows ?? this.windows,
        multiSelectionTool: multiSelectionTool ?? this.multiSelectionTool,
        webSocket: webSocket ?? this.webSocket,
        globalQuery: globalQuery,
        obsDate: obsDate,
      );

  /// Because the global query can be null, we need a special copy method.
  Workspace updateGlobalQuery(Query? query) => Workspace(
        theme: theme,
        windows: windows,
        multiSelectionTool: multiSelectionTool,
        webSocket: webSocket,
        globalQuery: query,
        obsDate: obsDate,
      );

  /// Becayse the obsDate can be null, we need a special copy method.
  Workspace updateObsDate(DateTime? obsDate) => Workspace(
        theme: theme,
        windows: windows,
        multiSelectionTool: multiSelectionTool,
        webSocket: webSocket,
        globalQuery: globalQuery,
        obsDate: obsDate,
      );

  /// Protect [_windows] so that it can only be updated through the app.
  Map<UniqueId, Window> get windows => {..._windows};

  /// Add a new [Window] to the [WorkspaceWidgetState].
  /// Normally the [index] is already created, unless
  /// the workspace is being loaded from disk.
  Workspace addWindow(Window window) {
    Map<UniqueId, Window> newWindows = {..._windows};
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
    action.dataCenter.addDatabaseSchema(message["content"]);
  } else if (message["type"] == "table columns") {
    print("received ${message["content"]["data"].length} columns for ${message["requestId"]}");
    action.dataCenter.updateSeriesData(
      seriesId: SeriesId.fromString(message["requestId"] as String),
      dataSourceName: message["content"]["schema"],
      plotColumns: List<String>.from(message["content"]["columns"].map((e) => e)),
      data: Map<String, List<dynamic>>.from(
          message["content"]["data"].map((key, value) => MapEntry(key, List<dynamic>.from(value)))),
      workspace: state.currentState,
    );
    print("dataCenter data: ${action.dataCenter.seriesIds}");
  }
  return state;
}

/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> updateWindowReducer(
  TimeMachine<Workspace> state,
  ApplyWindowUpdate action,
) {
  Workspace workspace = state.currentState;
  Map<UniqueId, Window> windows = {...workspace.windows};
  Window window = windows[action.windowId]!.copyWith(offset: action.offset, size: action.size);
  windows[window.id] = window;
  workspace = workspace.copyWith(windows: windows);

  return state.updated(TimeMachineUpdate(
    comment: "update a window size and position",
    state: workspace,
  ));
}

class UpdateChartGlobalQueryAction extends UiAction {
  final UniqueId chartId;
  final bool useGlobalQuery;
  final DataCenter dataCenter;
  UpdateChartGlobalQueryAction({
    required this.useGlobalQuery,
    required this.dataCenter,
    required this.chartId,
  });
}

String? getFormattedDate(DateTime? obsDate) {
  if (obsDate == null) {
    return null;
  }
  String year = obsDate.year.toString();
  String month = obsDate.month.toString().padLeft(2, '0');
  String day = obsDate.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

void getSeriesData(Workspace workspace, {ChartWindow? chart}) {
  String? obsDate = getFormattedDate(workspace.obsDate);

  late final List<ChartWindow> charts;
  if (chart != null) {
    charts = [chart];
  } else {
    charts = workspace.windows.values.whereType<ChartWindow>().toList();
  }
  // Request the data from the server.
  if (workspace.webSocket != null) {
    for (ChartWindow chart in charts) {
      for (SeriesInfo series in chart.series.values) {
        workspace.webSocket!.sink.add(LoadColumnsCommand.build(
          seriesId: series.id,
          fields: series.fields.values.toList(),
          query: series.query,
          useGlobalQuery: chart.useGlobalQuery,
          globalQuery: workspace.globalQuery,
          obsDate: obsDate,
        ).toJson());
      }
    }
  }
}

TimeMachine<Workspace> updateChartGlobalQueryReducer(
  TimeMachine<Workspace> state,
  UpdateChartGlobalQueryAction action,
) {
  Workspace workspace = state.currentState;
  Map<UniqueId, Window> windows = {...workspace.windows};
  ChartWindow chart = windows[action.chartId] as ChartWindow;
  chart = chart.copyWith(useGlobalQuery: action.useGlobalQuery);
  windows[chart.id] = chart;

  workspace = workspace.copyWith(windows: windows);
  getSeriesData(workspace, chart: chart);

  return state.updated(TimeMachineUpdate(
    comment: "update chart global query",
    state: workspace,
  ));
}

class UpdateGlobalQueryAction extends UiAction {
  final Query? query;

  const UpdateGlobalQueryAction({required this.query});
}

TimeMachine<Workspace> updateGlobalQueryReducer(
  TimeMachine<Workspace> state,
  UpdateGlobalQueryAction action,
) {
  Workspace workspace = state.currentState;
  workspace = workspace.updateGlobalQuery(action.query);
  getSeriesData(workspace);
  return state.updated(TimeMachineUpdate(
    comment: "update global query",
    state: workspace,
  ));
}

class UpdateGlobalObsDateAction extends UiAction {
  final DateTime? obsDate;

  const UpdateGlobalObsDateAction({required this.obsDate});
}

TimeMachine<Workspace> updateGlobalObsDateReducer(
  TimeMachine<Workspace> state,
  UpdateGlobalObsDateAction action,
) {
  print("updating date to ${action.obsDate}!");
  Workspace workspace = state.currentState;
  workspace = workspace.updateObsDate(action.obsDate);
  getSeriesData(workspace);
  return state.updated(TimeMachineUpdate(
    comment: "update global observation date",
    state: workspace,
  ));
}

/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> newChartReducer(
  TimeMachine<Workspace> state,
  CreateNewChartAction action,
) {
  Workspace workspace = state.currentState;
  Offset offset = workspace.theme.newWindowOffset;

  if (workspace.windows.isNotEmpty) {
    // Shift from last window
    offset += workspace.windows.values.last.offset;
  }

  workspace = workspace.addWindow(ChartWindow.fromChartType(
    id: UniqueId.next(),
    offset: offset,
    size: workspace.theme.newPlotSize,
    chartType: action.chartType,
  ));

  return state.updated(TimeMachineUpdate(
    comment: "add new Cartesian plot",
    state: workspace,
  ));
}

TimeMachine<Workspace> createSeriesReducer(
  TimeMachine<Workspace> state,
  CreateSeriesAction action,
) {
  Workspace workspace = state.currentState;
  ChartWindow chart = workspace.windows[action.series.id.windowId] as ChartWindow;
  chart = chart.addSeries(series: action.series);
  print("chart series keys are ${chart.series.keys}");
  workspace = workspace.copyWith(windows: {...workspace.windows, chart.id: chart});
  print("in workspace: ${(workspace.windows[chart.id]! as ChartWindow).series.keys}");

  return state.updated(TimeMachineUpdate(
    comment: "add new Series",
    state: workspace,
  ));
}

/// Update [SeriesData] in the [DataCenter].
TimeMachine<Workspace> updateSeriesReducer(
  TimeMachine<Workspace> state,
  SeriesUpdateAction action,
) {
  ChartWindow chart = state.currentState._windows[action.series.id.windowId] as ChartWindow;
  late String comment = "update Series";

  if (action.groupByColumn != null) {
    throw UnimplementedError();
    // Create a collection of series grouped by the specified column
    /*SchemaField field = action.groupByColumn!;

    Set unique = {};
    for(dynamic index in indices){
      Map<String, dynamic> record = dataSet.data[index]!;
      unique.add(record[field.name]);
    }

    developer.log("Creating ${unique.length} new series", name: "rubin_chart.workspace");

    for(dynamic value in unique){
      Series series = action.series;

      Query groupQuery = EqualityQuery(
        columnField: field,
        rightCondition: EqualityCondition(
          operator: EqualityOperator.eq,
          value: value,
        ),
      );

      Query query = groupQuery;

      if(series.query != null){
        query = ParentQuery(
          children: [series.query!, groupQuery],
          operator: QueryOperator.and,
        );
      }
      series = series.copyWith(name: value, query: query);
      chart = chart.addSeries(series: series, dataCenter: action.dataCenter);
    }*/
  } else if (chart.series.keys.contains(action.series.id)) {
    Map<SeriesId, SeriesInfo> newSeries = {...chart.series};
    newSeries[action.series.id] = action.series;
    chart = chart.copyWith(series: newSeries);
  } else {
    chart = chart.addSeries(series: action.series);
    comment = "add new Series";
  }

  Workspace workspace = state.currentState;
  Map<UniqueId, Window> windows = {...workspace.windows};
  windows[chart.id] = chart;

  // Request the data from the server.
  if (workspace.webSocket != null) {
    String? obsDate = getFormattedDate(workspace.obsDate);
    Query? query = action.series.query;
    workspace.webSocket!.sink.add(LoadColumnsCommand.build(
            seriesId: action.series.id,
            fields: action.series.fields.values.toList(),
            query: query,
            globalQuery: workspace.globalQuery,
            useGlobalQuery: chart.useGlobalQuery,
            obsDate: obsDate)
        .toJson());
  }

  return state.updated(TimeMachineUpdate(
    comment: comment,
    state: workspace.copyWith(windows: windows),
  ));
}

/// Reduce a [TimeMachineAction] and (potentially) update the history and workspace.
TimeMachine<Workspace> timeMachineReducer(TimeMachine<Workspace> state, TimeMachineAction action) {
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

/// Add a new cartesian plot to the workspace
TimeMachine<Workspace> removeWindowReducer(
  TimeMachine<Workspace> state,
  RemoveWindowAction action,
) {
  Workspace workspace = state.currentState;
  Map<UniqueId, Window> windows = {...workspace.windows};
  windows.remove(action.window.id);
  workspace = workspace.copyWith(windows: windows);

  return state.updated(TimeMachineUpdate(
    comment: "remove chart",
    state: workspace,
  ));
}

/// Handle a workspace action
Reducer<TimeMachine<Workspace>> workspaceReducer = combineReducers<TimeMachine<Workspace>>([
  TypedReducer<TimeMachine<Workspace>, TimeMachineAction>(timeMachineReducer),
  TypedReducer<TimeMachine<Workspace>, ApplyWindowUpdate>(updateWindowReducer),
  TypedReducer<TimeMachine<Workspace>, WebSocketReceiveMessageAction>(webSocketReceiveMessageReducer),
  TypedReducer<TimeMachine<Workspace>, CreateNewChartAction>(newChartReducer),
  TypedReducer<TimeMachine<Workspace>, UpdateGlobalQueryAction>(updateGlobalQueryReducer),
  TypedReducer<TimeMachine<Workspace>, UpdateGlobalObsDateAction>(updateGlobalObsDateReducer),
  TypedReducer<TimeMachine<Workspace>, SeriesUpdateAction>(updateSeriesReducer),
  TypedReducer<TimeMachine<Workspace>, UpdateChartGlobalQueryAction>(updateChartGlobalQueryReducer),
  TypedReducer<TimeMachine<Workspace>, RemoveWindowAction>(removeWindowReducer),
  TypedReducer<TimeMachine<Workspace>, CreateSeriesAction>(createSeriesReducer),
  /*TypedReducer<TimeMachine<Workspace>, AxisUpdate>(updateAxisReducer),
  TypedReducer<TimeMachine<Workspace>, RectSelectionAction>(
      rectSelectionReducer),
  TypedReducer<TimeMachine<Workspace>, PointSelectionAction>(
      pointSelectionReducer),
  TypedReducer<TimeMachine<Workspace>, RectZoomAction>(rectZoomReducer),
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
    final WorkspaceViewerState? result = context.findAncestorStateOfType<WorkspaceViewerState>();
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('WorkspaceViewer.of() called with a context that does not '
              'contain a WorkspaceViewer.'),
          ErrorDescription('No WorkspaceViewer ancestor could be found starting from the context '
              'that was passed to WorkspaceViewer.of().'),
          ErrorHint('This probably happened when an interactive child was created '
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
  AppTheme get theme => widget.workspace.theme;
  Size get size => widget.size;
  Workspace get info => widget.workspace;
  DataCenter get dataCenter => widget.dataCenter;
  DispatchAction get dispatch => widget.dispatch;

  WindowInteractionInfo? interactionInfo;
  late SelectionController selectionController;
  late SelectionController drillDownController;

  @override
  void initState() {
    super.initState();
    selectionController = SelectionController();
    drillDownController = SelectionController();
  }

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
                if (interactionInfo != null && window.id == interactionInfo!.id) {
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
      interaction.offset = update.details.localPosition + (interactionInfo as WindowDragInfo).pointerOffset;
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
    Offset deltaPosition = update.details.globalPosition - interaction.initialPointerOffset;

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
