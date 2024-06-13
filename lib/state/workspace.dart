import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/menu.dart';
import 'package:rubintv_visualization/workspace/series.dart';
import 'package:rubintv_visualization/workspace/toolbar.dart';
import 'package:rubintv_visualization/workspace/window.dart';

abstract class WorkspaceEvent {}

/// A message received via the websocket.
class ReceiveMessageEvent extends WorkspaceEvent {
  final Map<String, dynamic> message;

  ReceiveMessageEvent(this.message);
}

/// Update whether or not to use the global query for a given chart.
class UpdateChartGlobalQueryEvent extends WorkspaceEvent {
  final UniqueId chartId;
  final bool useGlobalQuery;

  UpdateChartGlobalQueryEvent({
    required this.useGlobalQuery,
    required this.chartId,
  });
}

/// Update the global query.
class UpdateGlobalQueryEvent extends WorkspaceEvent {
  final Query? globalQuery;

  UpdateGlobalQueryEvent({
    required this.globalQuery,
  });
}

/// Update the global observation date.
class UpdateGlobalObsDateEvent extends WorkspaceEvent {
  final DateTime? obsDate;

  UpdateGlobalObsDateEvent({required this.obsDate});
}

/// State of a [WorkspaceViewer].
abstract class WorkspaceState {
  const WorkspaceState();
}

/// The initial state of the [WorkspaceViewer].
class WorkspaceStateInitial extends WorkspaceState {}

/// A fully loaded state of the [WorkspaceViewer].
class WorkspaceStateLoaded extends WorkspaceState {
  /// Windows to display in the [WorkspaceStateLoaded].
  final Map<UniqueId, Window> windows;

  /// A query that applies to all plots (that opt in to gloabl queries)
  final Query? globalQuery;

  /// The observation date for any tables that have an observation date column.
  final DateTime? obsDate;

  /// The current instrument being analyzed.
  final Instrument instrument;

  /// The current detector being analyzed.
  /// If null, then no detector is selected.
  final Detector? detector;

  /// Whether or not to show the focal plane.
  final bool showFocalPlane;

  final AppTheme theme;

  const WorkspaceStateLoaded({
    required this.windows,
    required this.instrument,
    required this.showFocalPlane,
    required this.globalQuery,
    required this.obsDate,
    required this.detector,
    required this.theme,
  });

  /// Copy the [WorkspaceStateLoaded] with new values.
  WorkspaceStateLoaded copyWith({
    Map<UniqueId, Window>? windows,
    Instrument? instrument,
    Detector? detector,
    bool? showFocalPlane,
    FocalPlane? focalPlane,
    AppTheme? theme,
  }) =>
      WorkspaceStateLoaded(
        windows: windows ?? this.windows,
        globalQuery: globalQuery,
        obsDate: obsDate,
        instrument: instrument ?? this.instrument,
        detector: detector ?? this.detector,
        showFocalPlane: showFocalPlane ?? this.showFocalPlane,
        theme: theme ?? this.theme,
      );

  /// Because the global query can be null, we need a special copy method.
  WorkspaceStateLoaded updateGlobalQuery(Query? query) => WorkspaceStateLoaded(
        windows: windows,
        instrument: instrument,
        globalQuery: query,
        obsDate: obsDate,
        detector: detector,
        showFocalPlane: showFocalPlane,
        theme: theme,
      );

  /// Becayse the obsDate can be null, we need a special copy method.
  WorkspaceStateLoaded updateObsDate(DateTime? obsDate) => WorkspaceStateLoaded(
        windows: windows,
        instrument: instrument,
        globalQuery: globalQuery,
        obsDate: obsDate,
        detector: detector,
        showFocalPlane: showFocalPlane,
        theme: theme,
      );

  // Because the detector can be null, we need a special copy method.
  WorkspaceStateLoaded updateSelectedDetector(Detector? detector) => WorkspaceStateLoaded(
        windows: windows,
        instrument: instrument,
        globalQuery: globalQuery,
        obsDate: obsDate,
        detector: detector,
        showFocalPlane: showFocalPlane,
        theme: theme,
      );

  /// Add a new [Window] to the [WorkspaceWidgetState].
  /// Normally the [index] is already created, unless
  /// the workspace is being loaded from disk.
  WorkspaceStateLoaded addWindow(Window window) {
    Map<UniqueId, Window> newWindows = {...windows};
    newWindows[window.id] = window;

    return copyWith(
      windows: newWindows,
    );
  }
}

/// Get a formatted date string from a [DateTime].
String? getFormattedDate(DateTime? obsDate) {
  if (obsDate == null) {
    return null;
  }
  String year = obsDate.year.toString();
  String month = obsDate.month.toString().padLeft(2, '0');
  String day = obsDate.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

/// Load data for all series in a given chart
void getSeriesData(WorkspaceStateLoaded workspace, {ChartWindow? chart}) {
  String? obsDate = getFormattedDate(workspace.obsDate);

  late final List<ChartWindow> charts;
  if (chart != null) {
    charts = [chart];
  } else {
    charts = workspace.windows.values.whereType<ChartWindow>().toList();
  }
  // Request the data from the server.
  if (WebSocketManager().isConnected) {
    for (ChartWindow chart in charts) {
      for (SeriesInfo series in chart.series.values) {
        WebSocketManager().sendMessage(LoadColumnsCommand.build(
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

class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceState> {
  late StreamSubscription _subscription;

  WorkspaceBloc() : super(WorkspaceStateInitial()) {
    /// Listen for messages from the websocket.
    _subscription = WebSocketManager().messages.listen((message) {
      add(ReceiveMessageEvent(message));
    });

    /// A message is received from the websocket.
    on<ReceiveMessageEvent>((event, emit) {
      if (event.message["type"] == "instrument info") {
        // Update the workspace to use the new instrument
        Instrument instrument = Instrument.fromJson(event.message["content"]);
        emit((state as WorkspaceStateLoaded).copyWith(instrument: instrument));
      }
    });

    /// Update whether or not a chart uses the global query.
    on<UpdateChartGlobalQueryEvent>((event, emit) {
      WorkspaceStateLoaded state = this.state as WorkspaceStateLoaded;
      Map<UniqueId, Window> windows = {...state.windows};
      ChartWindow chart = windows[event.chartId] as ChartWindow;
      chart = chart.copyWith(useGlobalQuery: event.useGlobalQuery);
      windows[chart.id] = chart;
      state = state.copyWith(windows: windows);
      getSeriesData(state, chart: chart);
      emit(state);
    });

    /// Update the global query.
    on<UpdateGlobalQueryEvent>((event, emit) {
      WorkspaceStateLoaded state = this.state as WorkspaceStateLoaded;
      state = state.updateGlobalQuery(event.globalQuery);
      getSeriesData(state);
      emit(state);
    });

    /// Update the global observation date.
    on<UpdateGlobalObsDateEvent>((event, emit) {
      developer.log("updating date to ${event.obsDate}!", name: "rubin_chart.workspace");
      WorkspaceStateLoaded state = this.state as WorkspaceStateLoaded;
      state = state.updateObsDate(event.obsDate);
      getSeriesData(state);
      emit(state);
    });

    /// Create a new chart
    on<CreateNewChartEvent>((event, emit) {
      WorkspaceStateLoaded state = this.state as WorkspaceStateLoaded;
      Offset offset = state.theme.newWindowOffset;

      if (state.windows.isNotEmpty) {
        // Shift from last window
        offset += state.windows.values.last.offset;
      }

      ChartWindow chart = ChartWindow.fromChartType(
        id: UniqueId.next(),
        offset: offset,
        size: state.theme.newPlotSize,
        chartType: event.chartType,
      );
      Map<UniqueId, Window> windows = {...state.windows};
      windows[chart.id] = chart;
      emit(state.copyWith(windows: windows));
    });
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
TimeMachine<WorkspaceStateLoaded> webSocketReceiveMessageReducer(
  TimeMachine<WorkspaceStateLoaded> state,
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
  }
}

TimeMachine<WorkspaceStateLoaded> createSeriesReducer(
  TimeMachine<WorkspaceStateLoaded> state,
  CreateSeriesAction action,
) {
  WorkspaceStateLoaded workspace = state.currentState;
  ChartWindow chart = workspace.windows[action.series.id.windowId] as ChartWindow;
  chart = chart.addSeries(series: action.series);
  workspace = workspace.copyWith(windows: {...workspace.windows, chart.id: chart});

  return state.updated(TimeMachineUpdate(
    comment: "add new Series",
    state: workspace,
  ));
}

/// Update [SeriesData] in the [DataCenter].
TimeMachine<WorkspaceStateLoaded> updateSeriesReducer(
  TimeMachine<WorkspaceStateLoaded> state,
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

  WorkspaceStateLoaded workspace = state.currentState;
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

TimeMachine<WorkspaceStateLoaded> updateMultiSelectReducer(
  TimeMachine<WorkspaceStateLoaded> state,
  UpdateMultiSelect action,
) {
  WorkspaceStateLoaded workspace = state.currentState;
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

TimeMachine<WorkspaceStateLoaded> updateChartBinsReducer(
  TimeMachine<WorkspaceStateLoaded> state,
  UpdateChartBinsAction action,
) {
  WorkspaceStateLoaded workspace = state.currentState;
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

TimeMachine<WorkspaceStateLoaded> showFocalPlaneReducer(
  TimeMachine<WorkspaceStateLoaded> state,
  ShowFocalPlane action,
) {
  for (Window window in state.currentState.windows.values) {
    if (window is FocalPlane) {
      return state;
    }
  }

  WorkspaceStateLoaded workspace = state.currentState;
  Offset offset = workspace.theme.newWindowOffset;

  if (workspace.windows.isNotEmpty) {
    // Shift from last window
    offset += workspace.windows.values.last.offset;
  }

  workspace = workspace.addWindow(FocalPlane(
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

TimeMachine<WorkspaceStateLoaded> selectDetectorReducer(
  TimeMachine<WorkspaceStateLoaded> state,
  SelectDetectorAction action,
) {
  WorkspaceStateLoaded workspace = state.currentState;
  Map<UniqueId, Window> windows = {...workspace.windows};

  if (workspace.detector == action.detector) {
    // The user unselected the detector.
    WorkspaceStateLoaded newState = workspace.updateSelectedDetector(null);
    return state.updated(TimeMachineUpdate(
      comment: "deselect detector",
      state: newState,
    ));
  }

  WorkspaceStateLoaded newState = workspace.updateSelectedDetector(action.detector);
  return state.updated(TimeMachineUpdate(
    comment: "select detector",
    state: newState,
  ));
}

/// Reduce a [TimeMachineAction] and (potentially) update the history and workspace.
TimeMachine<WorkspaceStateLoaded> timeMachineReducer(
    TimeMachine<WorkspaceStateLoaded> state, TimeMachineAction action) {
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
TimeMachine<WorkspaceStateLoaded> removeWindowReducer(
  TimeMachine<WorkspaceStateLoaded> state,
  RemoveWindowAction action,
) {
  WorkspaceStateLoaded workspace = state.currentState;
  Map<UniqueId, Window> windows = {...workspace.windows};
  windows.remove(action.window.id);
  workspace = workspace.copyWith(windows: windows);

  return state.updated(TimeMachineUpdate(
    comment: "remove chart",
    state: workspace,
  ));
}

/// A [Widget] used to display a set of re-sizable and translatable [Window] widgets in a container.
class WorkspaceViewer extends StatefulWidget {
  final Size size;
  final DataCenter dataCenter;
  final AppTheme theme;

  const WorkspaceViewer({
    super.key,
    required this.size,
    required this.dataCenter,
    required this.theme,
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
  WorkspaceStateLoaded get info => widget.workspace;
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
