import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/image/focal_plane.dart';
import 'package:rubintv_visualization/state/chart.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/focal_plane.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/time_machine.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/menu.dart';
import 'package:rubintv_visualization/workspace/series.dart';
import 'package:rubintv_visualization/workspace/toolbar.dart';
import 'package:rubintv_visualization/workspace/window.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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

  // The websocket connection to the analysis service.
  final WebSocketChannel? webSocket;

  final Instrument? instrument;

  final Detector? detector;

  const Workspace({
    required this.theme,
    Map<UniqueId, Window> windows = const {},
    this.webSocket,
    this.globalQuery,
    this.obsDate,
    this.instrument,
    this.detector,
  }) : _windows = windows;

  Workspace copyWith({
    AppTheme? theme,
    Map<UniqueId, Window>? windows,
    WebSocketChannel? webSocket,
    Instrument? instrument,
  }) =>
      Workspace(
        theme: theme ?? this.theme,
        windows: windows ?? this.windows,
        webSocket: webSocket ?? this.webSocket,
        globalQuery: globalQuery,
        obsDate: obsDate,
        instrument: instrument ?? this.instrument,
        detector: detector ?? this.detector,
      );

  /// Because the global query can be null, we need a special copy method.
  Workspace updateGlobalQuery(Query? query) => Workspace(
        theme: theme,
        windows: windows,
        webSocket: webSocket,
        globalQuery: query,
        obsDate: obsDate,
        instrument: instrument,
        detector: detector,
      );

  /// Becayse the obsDate can be null, we need a special copy method.
  Workspace updateObsDate(DateTime? obsDate) => Workspace(
        theme: theme,
        windows: windows,
        webSocket: webSocket,
        globalQuery: globalQuery,
        obsDate: obsDate,
        instrument: instrument,
        detector: detector,
      );

  // Because the detector can be null, we need a special copy method.
  Workspace updateSelectedDetector(Detector? detector) => Workspace(
        theme: theme,
        windows: windows,
        webSocket: webSocket,
        globalQuery: globalQuery,
        obsDate: obsDate,
        instrument: instrument,
        detector: detector,
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

  bool get isShowingFocalPlane => _windows.values.any((element) => element is FocalPlaneWindow);
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
  if (message["type"] == "table columns") {
    developer.log("received ${message["content"]["data"].length} columns for ${message["requestId"]}",
        name: "rubin_chart.workspace");
    action.dataCenter.updateSeriesData(
      seriesId: SeriesId.fromString(message["requestId"] as String),
      dataSourceName: message["content"]["schema"],
      plotColumns: List<String>.from(message["content"]["columns"].map((e) => e)),
      data: Map<String, List<dynamic>>.from(
          message["content"]["data"].map((key, value) => MapEntry(key, List<dynamic>.from(value)))),
      workspace: state.currentState,
    );
    developer.log("dataCenter data: ${action.dataCenter.seriesIds}", name: "rubin_chart.workspace");
  } else if (message["type"] == "instrument info") {
    // Update the data center to use the new instrument
    if (message["content"].containsKey("schema")) {
      action.dataCenter.addDatabaseSchema(message["content"]["schema"]);
    }

    // Update the workspace to use the new instrument
    Instrument instrument = Instrument.fromJson(message["content"]);
    Workspace newState = state.currentState.copyWith(instrument: instrument);
    if (newState.detector != null) {
      newState = newState.updateSelectedDetector(null);
    }
    if (newState.isShowingFocalPlane) {
      Map<UniqueId, Window> windows = {...newState.windows};
      for (Window window in newState.windows.values) {
        if (window is FocalPlaneWindow) {
          windows[window.id] = window.copyWith(instrument: instrument);
        }
      }
      newState = newState.copyWith(windows: windows);
    }
    return state.updated(TimeMachineUpdate(
      comment: "update instrument info",
      state: newState,
    ));
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
  developer.log("updating date to ${action.obsDate}!", name: "rubin_chart.workspace");
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
  workspace = workspace.copyWith(windows: {...workspace.windows, chart.id: chart});

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
    List<ChartAxisInfo> axesInfo = [for (var axis in chart.axes) axis!];
    for (int i = 0; i < axesInfo.length; i++) {
      ChartAxisInfo axisInfo = axesInfo[i];
      if (axisInfo.label.startsWith("<") && axisInfo.label.endsWith(">")) {
        axesInfo[i] = axisInfo.copyWith(label: action.series.fields.values.toList()[i].name);
      }
    }
    chart = chart.copyWith(series: newSeries, axisInfo: axesInfo);
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

TimeMachine<Workspace> updateMultiSelectReducer(
  TimeMachine<Workspace> state,
  UpdateMultiSelect action,
) {
  Workspace workspace = state.currentState;
  Map<UniqueId, Window> windows = {...workspace.windows};
  ChartWindow chart = windows[action.chartId] as ChartWindow;
  if (chart is ScatterChartWindow) {
    chart = chart.copyWith(tool: action.tool);
  } else if (chart is BinnedChartWindow) {
    chart = chart.copyWith(tool: action.tool);
  } else {
    throw UnimplementedError("Unrecognized chart type: $chart");
  }
  windows[chart.id] = chart;
  workspace = workspace.copyWith(windows: windows);
  return state.updated(TimeMachineUpdate(
    comment: "update multi-selection tool",
    state: workspace,
  ));
}

TimeMachine<Workspace> updateChartBinsReducer(
  TimeMachine<Workspace> state,
  UpdateChartBinsAction action,
) {
  Workspace workspace = state.currentState;
  Map<UniqueId, Window> windows = {...workspace.windows};
  BinnedChartWindow chart = windows[action.chartId] as BinnedChartWindow;
  chart = chart.copyWith(nBins: action.nBins);
  windows[chart.id] = chart;
  workspace = workspace.copyWith(windows: windows);
  developer.log("Updating chart bins to ${action.nBins}", name: "rubin_chart.workspace");
  return state.updated(TimeMachineUpdate(
    comment: "update chart bins",
    state: workspace,
  ));
}

TimeMachine<Workspace> showFocalPlaneReducer(
  TimeMachine<Workspace> state,
  ShowFocalPlane action,
) {
  for (Window window in state.currentState.windows.values) {
    if (window is FocalPlaneWindow) {
      return state;
    }
  }

  Workspace workspace = state.currentState;
  Offset offset = workspace.theme.newWindowOffset;

  if (workspace.windows.isNotEmpty) {
    // Shift from last window
    offset += workspace.windows.values.last.offset;
  }

  workspace = workspace.addWindow(FocalPlaneWindow(
    id: UniqueId.next(),
    offset: offset,
    size: workspace.theme.newPlotSize,
    instrument: workspace.instrument!,
  ));

  return state.updated(TimeMachineUpdate(
    comment: "add new Focal Plane",
    state: workspace,
  ));
}

TimeMachine<Workspace> selectDetectorReducer(
  TimeMachine<Workspace> state,
  SelectDetectorAction action,
) {
  Workspace workspace = state.currentState;
  Map<UniqueId, Window> windows = {...workspace.windows};

  if (workspace.detector == action.detector) {
    // The user unselected the detector.
    Workspace newState = workspace.updateSelectedDetector(null);
    return state.updated(TimeMachineUpdate(
      comment: "deselect detector",
      state: newState,
    ));
  }

  Workspace newState = workspace.updateSelectedDetector(action.detector);
  return state.updated(TimeMachineUpdate(
    comment: "select detector",
    state: newState,
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
  TypedReducer<TimeMachine<Workspace>, UpdateMultiSelect>(updateMultiSelectReducer),
  TypedReducer<TimeMachine<Workspace>, ShowFocalPlane>(showFocalPlaneReducer),
  TypedReducer<TimeMachine<Workspace>, SelectDetectorAction>(selectDetectorReducer),
  TypedReducer<TimeMachine<Workspace>, UpdateChartBinsAction>(updateChartBinsReducer),
  /*TypedReducer<TimeMachine<Workspace>, AxisUpdate>(updateAxisReducer),
  TypedReducer<TimeMachine<Workspace>, RectSelectionAction>(
      rectSelectionReducer),
  TypedReducer<TimeMachine<Workspace>, PointSelectionAction>(
      pointSelectionReducer),
  TypedReducer<TimeMachine<Workspace>, RectZoomAction>(rectZoomReducer),*/
]);

/// A [Widget] used to display a set of re-sizable and translatable [Window] widgets in a container.
class WorkspaceViewer extends StatefulWidget {
  final Size size;
  final Workspace workspace;
  final DataCenter dataCenter;
  final DispatchAction dispatch;
  final bool isConnected;
  final bool isFirstFrame;
  final bool isLastFrame;

  const WorkspaceViewer({
    super.key,
    required this.size,
    required this.workspace,
    required this.dataCenter,
    required this.dispatch,
    required this.isConnected,
    required this.isFirstFrame,
    required this.isLastFrame,
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

class SelectDataPointsCommand {
  final Set<DataId> dataPoints;

  SelectDataPointsCommand({
    required this.dataPoints,
  });

  Map<String, dynamic> toJson() {
    return {
      "type": "select data points",
      "dataPoints": dataPoints.map((e) => e.toJson()).toList(),
    };
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
    developer.log("Initializing WorkspaceViewerState", name: "rubin_chart.workspace");
    super.initState();
    selectionController = SelectionController();
    drillDownController = SelectionController();

    selectionController.subscribe(_onSelectionUpdate);
  }

  /// Update the selection data points.
  void _onSelectionUpdate(Set<Object> dataPoints) {
    developer.log("Selection updated: $dataPoints", name: "rubin_chart.workspace");
    /*info.webSocket!.sink.add(SelectDataPointsCommand(
      dataPoints: dataPoints as Set<DataId>,
    ).toJson());*/
  }

  @override
  Widget build(BuildContext context) {
    return AppMenu(
      theme: theme,
      dispatch: dispatch,
      dataCenter: dataCenter,
      child: Column(children: [
        Toolbar(
          isConnected: widget.isConnected,
          isFirstFrame: widget.isFirstFrame,
          isLastFrame: widget.isLastFrame,
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
