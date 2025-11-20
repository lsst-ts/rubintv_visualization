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

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/chart/binned.dart';
import 'package:rubintv_visualization/focal_plane/chart.dart';
import 'package:rubintv_visualization/focal_plane/instrument.dart';
import 'package:rubintv_visualization/focal_plane/slider.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/primitives.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/window.dart';
import 'package:rubintv_visualization/error.dart';

/// Create an empty [ChartAxis].
/// This is required for the color map slider, and is just a dummy axis.
ChartAxis createEmptyDataAxis(ChartAxisInfo axisInfo, ChartTheme theme) {
  return NumericalChartAxis(
    info: axisInfo,
    bounds: const Bounds(0, 0),
    dataBounds: const Bounds(0, 0),
    ticks: AxisTicks(
      majorTicks: [],
      minorTicks: [],
      bounds: const Bounds(0, 0),
      tickLabels: [],
    ),
    theme: theme,
  );
}

FocalPlaneChartBloc buildFocalPlaneBloc({
  required UniqueId id,
  required WorkspaceState workspace,
  String? title,
}) {
  SeriesId sid = SeriesId(windowId: id, id: BigInt.zero);
  AxisId valueAxisId = AxisId(AxisLocation.right);
  AxisId detectorAxisId = AxisId(AxisLocation.color);
  Map<AxisId, SchemaField> fields = {};
  ChartAxisInfo axisInfo = ChartAxisInfo(
    label: "Focal Plane color axis",
    axisId: valueAxisId,
  );
  ChartAxis dataAxis = createEmptyDataAxis(axisInfo, workspace.theme.chartTheme);

  SeriesInfo newSeries = SeriesInfo(
    id: sid,
    name: "Focal Plane Chart",
    axes: [valueAxisId, detectorAxisId],
    fields: fields,
  );

  ColorbarController colorbarController = ColorbarController(
    min: 0,
    max: 100,
    stops: {
      0: Colors.blue,
      100: Colors.red,
    },
  );

  FocalPlaneChartState state = FocalPlaneChartState(
    id: id,
    series: newSeries,
    dataAxis: dataAxis,
    data: {},
    dataIds: [],
    dataIndex: 0,
    colorbarController: colorbarController,
    playbackSpeed: 1,
    isPlaying: false,
    loopPlayback: true,
    dayObs: getFormattedDate(workspace.dayObs),
  );

  FocalPlaneChartBloc result = FocalPlaneChartBloc(state);

  return result;
}

ChartBloc buildBinnedBloc({
  required UniqueId id,
  required WindowTypes windowType,
  String? title,
}) {
  final List<ChartAxisInfo> axisInfo = [
    ChartAxisInfo(
      label: "<x>",
      axisId: AxisId(AxisLocation.bottom),
    ),
  ];
  if (windowType == WindowTypes.box) {
    axisInfo.add(
      ChartAxisInfo(
        label: "<y>",
        axisId: AxisId(AxisLocation.left),
        isInverted: true,
      ),
    );
  }
  BinnedState state = BinnedState(
    id: id,
    series: {},
    axisInfo: axisInfo,
    legend: Legend(),
    useGlobalQuery: true,
    windowType: windowType,
    tool: MultiSelectionTool.select,
    nBins: 20,
    resetController: StreamController<ResetChartAction>.broadcast(),
  );
  return ChartBloc(state);
}

ChartBloc buildScatterBloc({
  required UniqueId id,
  required WindowTypes windowType,
  String? title,
}) {
  final List<ChartAxisInfo> axisInfo = [];
  if (windowType == WindowTypes.cartesianScatter) {
    axisInfo.addAll([
      ChartAxisInfo(
        label: "<x>",
        axisId: AxisId(AxisLocation.bottom),
      ),
      ChartAxisInfo(
        label: "<y>",
        axisId: AxisId(AxisLocation.left),
        isInverted: true,
      ),
    ]);
  } else if (windowType == WindowTypes.polarScatter) {
    axisInfo.addAll([
      ChartAxisInfo(
        label: "<r>",
        axisId: AxisId(AxisLocation.radial),
      ),
      ChartAxisInfo(
        label: "<θ>",
        axisId: AxisId(AxisLocation.angular),
        isInverted: true,
      ),
    ]);
  }

  ChartState state = ChartState(
    id: id,
    series: {},
    axisInfo: axisInfo,
    legend: Legend(),
    useGlobalQuery: true,
    windowType: windowType,
    tool: MultiSelectionTool.select,
    resetController: StreamController<ResetChartAction>.broadcast(),
  );

  return ChartBloc(state);
}

/// Create a new [WindowMetaData] instance.
WindowMetaData buildWindow({
  required UniqueId id,
  required WindowTypes windowType,
  required WorkspaceState workspace,
  String? title,
}) {
  // Shift the location from the last window
  Offset offset = workspace.theme.newWindowOffset;
  if (workspace.windows.isNotEmpty) {
    offset += workspace.windows.values.last.offset;
  }

  // Create the Bloc
  late final WindowBloc bloc;
  if (windowType.isBinned) {
    bloc = buildBinnedBloc(id: id, windowType: windowType);
  } else if (windowType.isScatter) {
    bloc = buildScatterBloc(id: id, windowType: windowType);
  } else if (windowType == WindowTypes.focalPlane) {
    bloc = buildFocalPlaneBloc(id: id, workspace: workspace, title: title);
  } else if (windowType == WindowTypes.detectorSelector) {
    bloc = WindowBloc(WindowState(id: id, windowType: WindowTypes.detectorSelector));
  } else {
    throw ArgumentError("Unknown window type $windowType");
  }

  return WindowMetaData(
    offset: offset,
    size: workspace.theme.newPlotSize,
    bloc: bloc,
    title: title,
  );
}

/// The global query parameters
class GlobalQuery {
  /// The global query.
  final QueryExpression? query;

  /// The global observation date.
  final String? dayObs;

  /// The current instrument being analyzed.
  final Instrument? instrument;

  /// The current detector that is selected.
  final Detector? detector;

  GlobalQuery({
    required this.query,
    required this.dayObs,
    required this.instrument,
    required this.detector,
  });
}

/// An event to update the workspace state.
abstract class WorkspaceEvent {}

/// Initialize the workspace.
class InitializeWorkspaceEvent extends WorkspaceEvent {
  /// The theme of the app.
  final AppTheme theme;

  final AppVersion version;

  InitializeWorkspaceEvent(this.theme, this.version);
}

/// A message received via the websocket.
class ReceiveMessageEvent extends WorkspaceEvent {
  /// The message received.
  final Map<String, dynamic> message;

  ReceiveMessageEvent(this.message);
}

/// Update the global query.
class UpdateGlobalQueryEvent extends WorkspaceEvent {
  /// The new global query.
  final QueryExpression? globalQuery;

  UpdateGlobalQueryEvent({
    required this.globalQuery,
  });
}

/// Update the global observation date.
class UpdateGlobalObsDateEvent extends WorkspaceEvent {
  /// The new observation date.
  final DateTime? dayObs;

  UpdateGlobalObsDateEvent({required this.dayObs});
}

/// Add a new [CartesianPlot] to the [WorkspaceViewer].
class CreateNewWindowEvent extends WorkspaceEvent {
  /// The type of window to create.
  final WindowTypes windowType;

  CreateNewWindowEvent({
    this.windowType = WindowTypes.cartesianScatter,
  });
}

/// Notify the [WorkspaceViewer] to show the full focal plane.
class ShowFocalPlaneEvent extends WorkspaceEvent {
  ShowFocalPlaneEvent();
}

/// Load a workspace from a JSON text string.
class LoadWorkspaceFromTextEvent extends WorkspaceEvent {
  final String text;

  LoadWorkspaceFromTextEvent(this.text);
}

/// Clear the DataCenter and the workspace
class ClearWorkspaceEvent extends WorkspaceEvent {
  final WorkspaceState? state;

  ClearWorkspaceEvent({this.state});
}

/// Update the workspace in the [WorkspaceBloc].
/// This should usually occur after a [ClearWorkspaceEvent]
/// to ensure that all data from the current workspace is cleared
/// and that all listener subscriptions have been closed.
class UpdateWorkspaceEvent extends WorkspaceEvent {
  final WorkspaceState state;

  UpdateWorkspaceEvent(this.state);
}

/// The status of a workspace.
enum WorkspaceStatus {
  initial,
  loadingInstrument,
  loadingWorkspace,
  ready,
  error,
}

/// State of a [WorkspaceViewer].
abstract class WorkspaceStateBase {
  /// The status of the workspace.
  final WorkspaceStatus status;

  const WorkspaceStateBase({
    required this.status,
  });
}

/// The initial state of the [WorkspaceViewer].
class WorkspaceStateInitial extends WorkspaceStateBase {
  const WorkspaceStateInitial() : super(status: WorkspaceStatus.initial);
}

/// A fully loaded state of the [WorkspaceViewer].
class WorkspaceState extends WorkspaceStateBase {
  /// The version of the application.
  final AppVersion version;

  /// Windows to display in the [WorkspaceState].
  final Map<UniqueId, WindowMetaData> windows;

  /// A query that applies to all plots (that opt in to gloabl queries)
  final QueryExpression? globalQuery;

  /// The observation date for any tables that have an observation date column.
  final DateTime? dayObs;

  /// The current instrument being analyzed.
  final Instrument? instrument;

  /// The current detector being analyzed.
  /// If null, then no detector is selected.
  final Detector? detector;

  /// The theme of the app
  final AppTheme theme;

  /// The current interaction info.
  final WindowInteractionInfo? interactionInfo;

  /// The error message, if any.
  final String? errorMessage;

  /// The JSON that is pending to be loaded, if any.
  final Map<String, dynamic>? pendingJson;

  @override
  String toString() {
    return "WorkspaceStateLoaded(windows: $windows, instrument: $instrument, globalQuery: $globalQuery, "
        "dayObs: $dayObs, detector: $detector, theme: $theme, interactionInfo: $interactionInfo)";
  }

  const WorkspaceState({
    required super.status,
    required this.version,
    required this.windows,
    this.instrument,
    this.globalQuery,
    this.dayObs,
    this.detector,
    required this.theme,
    this.interactionInfo,
    this.errorMessage,
    this.pendingJson,
  });

  /// Convert the [WorkspaceState] to a JSON object.
  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = {
      "windows": Map<String, dynamic>.fromEntries(
          windows.entries.map((e) => MapEntry(e.key.toSerializableString(), e.value.toJson()))),
      "version": version.toJson(),
    };
    if (instrument != null) {
      result["instrument"] = instrument!.toJson();
    }
    if (globalQuery != null) {
      result["globalQuery"] = globalQuery!.toJson();
    }
    if (dayObs != null) {
      result["dayObs"] = dayObs!.toIso8601String();
    }
    if (detector != null) {
      result["detector"] = detector!.toJson();
    }
    return result;
  }

  /// Create a [WorkspaceState] from a JSON object.
  static WorkspaceState fromJson(
    Map<String, dynamic> json,
    AppTheme theme,
    AppVersion version,
  ) {
    AppVersion fileVersion = AppVersion.fromJson(json["version"]);
    if (fileVersion != version) {
      developer.log("File version $fileVersion does not match current version $version. ",
          name: "rubintv.workspace");
      json = convertWorkspace(json, theme, version);
    }

    return WorkspaceState(
      version: AppVersion.fromJson(json["version"]),
      windows: (json["windows"] as Map<String, dynamic>).map((key, value) {
        return MapEntry(UniqueId.fromString(key), WindowMetaData.fromJson(value, theme.chartTheme));
      }),
      instrument: json.containsKey("instrument") ? Instrument.fromJson(json["instrument"]) : null,
      globalQuery: json.containsKey("globalQuery") ? QueryExpression.fromJson(json["globalQuery"]) : null,
      dayObs: json.containsKey("dayObs") ? DateTime.parse(json["dayObs"]) : null,
      detector: json.containsKey("detector") ? Detector.fromJson(json["detector"]) : null,
      theme: theme,
      interactionInfo: null,
      status: WorkspaceStatus.ready,
    );
  }

  /// Copy the [WorkspaceState] with new values.
  WorkspaceState copyWith({
    AppVersion? version,
    WorkspaceStatus? status,
    Map<UniqueId, WindowMetaData>? windows,
    Instrument? instrument,
    Detector? detector,
    bool? showFocalPlane,
    AppTheme? theme,
    String? errorMessage,
    Map<String, dynamic>? pendingJson,
  }) =>
      WorkspaceState(
          status: status ?? this.status,
          version: version ?? this.version,
          windows: windows ?? this.windows,
          globalQuery: globalQuery,
          dayObs: dayObs,
          instrument: instrument ?? this.instrument,
          detector: detector ?? this.detector,
          theme: theme ?? this.theme,
          interactionInfo: interactionInfo,
          errorMessage: errorMessage,
          pendingJson: pendingJson);

  /// Because the global query can be null, we need a special copy method.
  WorkspaceState updateGlobalQuery(QueryExpression? query) => WorkspaceState(
      status: status,
      version: version,
      windows: windows,
      instrument: instrument,
      globalQuery: query,
      dayObs: dayObs,
      detector: detector,
      theme: theme,
      interactionInfo: interactionInfo,
      errorMessage: errorMessage,
      pendingJson: pendingJson);

  /// Because the dayObs can be null, we need a special copy method.
  WorkspaceState updateObsDate(DateTime? dayObs) => WorkspaceState(
        status: status,
        version: version,
        windows: windows,
        instrument: instrument,
        globalQuery: globalQuery,
        dayObs: dayObs,
        detector: detector,
        theme: theme,
        interactionInfo: interactionInfo,
        errorMessage: errorMessage,
        pendingJson: pendingJson,
      );

  // Because the detector can be null, we need a special copy method.
  WorkspaceState updateSelectedDetector(Detector? detector) => WorkspaceState(
        status: status,
        version: version,
        windows: windows,
        instrument: instrument,
        globalQuery: globalQuery,
        dayObs: dayObs,
        detector: detector,
        theme: theme,
        interactionInfo: interactionInfo,
        errorMessage: errorMessage,
        pendingJson: pendingJson,
      );

  /// Update the interaction info.
  WorkspaceState updateInteractionInfo(WindowInteractionInfo? interactionInfo) => WorkspaceState(
        status: status,
        version: version,
        windows: windows,
        instrument: instrument,
        globalQuery: globalQuery,
        dayObs: dayObs,
        detector: detector,
        theme: theme,
        interactionInfo: interactionInfo,
        errorMessage: errorMessage,
        pendingJson: pendingJson,
      );

  /// Add a new [WindowMetaData] to the [WorkspaceWidgetState].
  /// Normally the [index] is already created, unless
  /// the workspace is being loaded from disk.
  WorkspaceState addWindow(WindowMetaData window) {
    Map<UniqueId, WindowMetaData> newWindows = {...windows};
    newWindows[window.id] = window;

    return copyWith(
      windows: newWindows,
    );
  }

  /// Whether or not the window is showing the focal plane.
  bool get isShowingFocalPlane =>
      windows.values.any((window) => window.windowType == WindowTypes.detectorSelector);

  /// Get the [GlobalQuery] for the workspace.
  GlobalQuery getGlobalQuery() {
    return GlobalQuery(
      query: globalQuery,
      dayObs: getFormattedDate(dayObs),
      instrument: instrument,
      detector: detector,
    );
  }
}

/// Get a formatted date string from a [DateTime].
String? getFormattedDate(DateTime? dayObs) {
  if (dayObs == null) {
    return null;
  }
  String year = dayObs.year.toString();
  String month = dayObs.month.toString().padLeft(2, '0');
  String day = dayObs.day.toString().padLeft(2, '0');

  return '$year-$month-$day';
}

/// Load data for all series in a given chart
void updateAllSeriesData(WorkspaceState workspace, {ChartState? chart}) {
  String? dayObs = getFormattedDate(workspace.dayObs);
  late final List<ChartState> charts;
  if (chart != null) {
    charts = [chart];
  } else {
    charts = workspace.windows.values.whereType<ChartState>().toList();
  }
  // Request the data from the server.
  if (WebSocketManager().isConnected) {
    for (ChartState chart in charts) {
      for (SeriesInfo series in chart.series.values) {
        WebSocketManager().sendMessage(LoadColumnsCommand.build(
          seriesId: series.id,
          fields: series.fields.values.toList(),
          query: series.query,
          useGlobalQuery: chart.useGlobalQuery,
          globalQuery: workspace.globalQuery,
          dayObs: dayObs,
          windowId: chart.id,
        ).toJson());
      }
    }
  }
}

/// A [Bloc] that manages the state of the [WorkspaceViewer].
class WorkspaceBloc extends Bloc<WorkspaceEvent, WorkspaceStateBase> {
  late StreamSubscription _subscription;

  WorkspaceBloc() : super(const WorkspaceStateInitial()) {
    /// Listen for messages from the websocket.
    _subscription = WebSocketManager().messages.listen((message) {
      add(ReceiveMessageEvent(message));
    });

    /// Initialize the workspace.
    on<InitializeWorkspaceEvent>((event, emit) {
      emit(WorkspaceState(
        status: WorkspaceStatus.ready,
        windows: {},
        theme: event.theme,
        version: event.version,
      ));
    });

    /// A message is received from the websocket.
    on<ReceiveMessageEvent>((event, emit) {
      developer.log("Workspace Received message: ${event.message["type"]}", name: "rubintv.workspace");
      if (event.message["type"] == "instrument info") {
        // Update the workspace to use the new instrument
        WorkspaceState state = this.state as WorkspaceState;
        Instrument instrument = Instrument.fromJson(event.message["content"]);

        // If we're already in a ready state and don't have pending JSON,
        // just update the instrument and don't trigger a full workspace reload
        if (state.status == WorkspaceStatus.ready && state.pendingJson == null) {
          emit(state.copyWith(instrument: instrument));
          return;
        }

        emit(state.copyWith(instrument: instrument));

        if (state.status == WorkspaceStatus.loadingInstrument && state.pendingJson != null) {
          // Build new workspace from JSON
          _applyWorkspaceJsonWithClear(emit, state.pendingJson!, state);
        }
      } else if (event.message["type"] == "file content") {
        // Load the workspace from the file content
        add(LoadWorkspaceFromTextEvent(event.message["content"]["content"]));
      } else if (event.message["type"] == "error") {
        // Display the error message
        developer.log("Received error message: ${event.message["content"]}", name: "rubintv.workspace");

        // Extract error details
        Map<String, dynamic> errorContent = event.message["content"];
        String errorType = errorContent["error"] ?? "Unknown Error";
        String description = errorContent["description"] ?? "No description provided";
        String? traceback = errorContent["traceback"];

        // Create user-friendly error message
        String userMessage = "$errorType: $description";
        if (traceback != null && traceback.isNotEmpty) {
          // Show a simplified version of the traceback
          List<String> traceLines = traceback.split('\\n');
          String lastError = traceLines.where((line) => line.trim().isNotEmpty).last;
          userMessage += "\nDetails: $lastError";
        }

        // Report the error to the UI
        reportError(userMessage);
      }
    });

    /// Update the global query.
    on<UpdateGlobalQueryEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      state = state.updateGlobalQuery(event.globalQuery);
      ControlCenter().updateGlobalQuery(state.getGlobalQuery());
      emit(state);
    });

    /// Update the global observation date.
    on<UpdateGlobalObsDateEvent>((event, emit) {
      developer.log("updating date to ${event.dayObs}!", name: "rubintv.workspace");
      WorkspaceState state = this.state as WorkspaceState;
      state = state.updateObsDate(event.dayObs);
      ControlCenter().updateGlobalQuery(state.getGlobalQuery());
      emit(state);
    });

    /// Create a new chart
    on<CreateNewWindowEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      WindowMetaData newWindow = buildWindow(
        id: UniqueId.next(),
        windowType: event.windowType,
        workspace: state,
      );
      Map<UniqueId, WindowMetaData> windows = {...state.windows};
      windows[newWindow.id] = newWindow;
      emit(state.copyWith(windows: windows));
    });

    /// Add a new window with the FocalPlane displayed.
    on<ShowFocalPlaneEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;

      // Make sure that the focal plane isn't already opened
      for (WindowMetaData window in state.windows.values) {
        if (window.windowType == WindowTypes.detectorSelector) {
          return;
        }
      }

      WindowMetaData newWindow = buildWindow(
        id: UniqueId.next(),
        windowType: WindowTypes.detectorSelector,
        workspace: state,
      );
      Map<UniqueId, WindowMetaData> windows = {...state.windows};
      windows[newWindow.id] = newWindow;

      developer.log("Added new focal plane window: $newWindow", name: "rubintv.workspace");

      emit(state.copyWith(windows: windows));
    });

    /// Select a detector to display in image windows.
    on<SelectDetectorEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      if (state.detector == event.detector) {
        emit(state.updateSelectedDetector(null));
        return;
      }
      emit(state.updateSelectedDetector(event.detector));
    });

    /// Remove a window from the workspace.
    on<RemoveWindowEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      Map<UniqueId, WindowMetaData> windows = {...state.windows};
      WindowMetaData? windowToRemove = windows[event.windowId];
      if (windowToRemove != null) {
        // Close the bloc to cancel all its subscriptions
        windowToRemove.bloc.close();

        // Remove the window from the map
        windows.remove(event.windowId);

        developer.log("Window ${event.windowId} removed and bloc closed", name: "rubintv.workspace.state");
      }
      emit(state.copyWith(windows: windows));
    });

    /// Keep track of the starting drag position
    on<WindowDragStartEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      if (state.interactionInfo != null) {
        state = state.updateInteractionInfo(null);
      }
      WindowMetaData window = state.windows[event.windowId]!;
      WindowInteractionInfo interactionInfo = WindowDragInfo(
        id: event.windowId,
        pointerOffset: window.offset - event.details.localPosition,
      );
      emit(state.updateInteractionInfo(interactionInfo));
    });

    /// Update the position of a window.
    on<WindowDragUpdate>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      if (state.interactionInfo is! WindowDragInfo) {
        state = state.updateInteractionInfo(null);
        throw Exception("Mismatched interactionInfo, got ${state.interactionInfo}");
      }
      Map<UniqueId, WindowMetaData> windows = {...state.windows};
      WindowMetaData window = windows[event.windowId]!;
      Offset offset = event.details.localPosition + (state.interactionInfo as WindowDragInfo).pointerOffset;
      window = window.copyWith(offset: offset);
      windows[event.windowId] = window;
      emit(state.copyWith(windows: windows));
    });

    /// End the drag interaction.
    on<WindowDragEndEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      emit(state.updateInteractionInfo(null));
    });

    /// Start a window resize interaction.
    on<StartWindowResize>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      if (state.interactionInfo != null) {
        state = state.updateInteractionInfo(null);
      }
      WindowMetaData window = state.windows[event.windowId]!;
      WindowInteractionInfo interactionInfo = WindowResizeInfo(
        id: event.windowId,
        initialPointerOffset: event.details.globalPosition,
        initialSize: window.size,
        initialOffset: window.offset,
      );
      emit(state.updateInteractionInfo(interactionInfo));
    });

    /// Update the window size during a resize interaction.
    on<UpdateWindowResize>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      if (state.interactionInfo is! WindowResizeInfo) {
        state = state.updateInteractionInfo(null);
        throw Exception("Mismatched interactionInfo, got ${state.interactionInfo}");
      }

      // Get the new offset and size
      WindowResizeInfo interaction = state.interactionInfo as WindowResizeInfo;
      Offset deltaPosition = event.details.globalPosition - interaction.initialPointerOffset;

      double left = interaction.initialOffset.dx;
      double top = interaction.initialOffset.dy;
      double width = interaction.initialSize.width;
      double height = interaction.initialSize.height;

      // Update the width and x-offset
      if (event.direction == WindowResizeDirections.right ||
          event.direction == WindowResizeDirections.downRight) {
        width = interaction.initialSize.width + deltaPosition.dx;
      } else if (event.direction == WindowResizeDirections.left ||
          event.direction == WindowResizeDirections.downLeft) {
        left = interaction.initialOffset.dx + deltaPosition.dx;
        width = interaction.initialSize.width - deltaPosition.dx;
      }

      // Update the height and y-offset
      if (event.direction == WindowResizeDirections.down ||
          event.direction == WindowResizeDirections.downLeft ||
          event.direction == WindowResizeDirections.downRight) {
        height = interaction.initialSize.height + deltaPosition.dy;
      }

      Offset offset = Offset(left, top);
      Size size = Size(width, height);

      // Update the window
      Map<UniqueId, WindowMetaData> windows = {...state.windows};
      WindowMetaData window = windows[event.windowId]!;
      window = window.copyWith(
        size: size,
        offset: offset,
      );
      windows[event.windowId] = window;
      emit(state.copyWith(windows: windows));
    });

    /// End the window resize interaction.
    on<EndWindowResize>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      emit(state.updateInteractionInfo(null));
    });

    /// Load a workspace from a text string.
    on<LoadWorkspaceFromTextEvent>(_onLoadWorkspaceFromText);

    /// Clear the workspace and DataCenter.
    on<ClearWorkspaceEvent>((event, emit) async {
      WorkspaceState state = this.state as WorkspaceState;
      await _clearWorkspace(state);
      add(InitializeWorkspaceEvent(state.theme, state.version));
    });

    /// Update the workspace state with a new state.
    on<UpdateWorkspaceEvent>((event, emit) {
      emit(event.state);
    });
  }

  /// Load a workspace from a text string.
  void _onLoadWorkspaceFromText(LoadWorkspaceFromTextEvent event, Emitter<WorkspaceStateBase> emit) {
    WorkspaceState state = this.state as WorkspaceState;

    developer.log("=== WORKSPACE LOAD START ===", name: "rubintv.workspace.load");
    developer.log("Current state: windows=${state.windows.length}, instrument=${state.instrument?.name}",
        name: "rubintv.workspace.load");

    try {
      Map<String, dynamic> json = jsonDecode(event.text);
      developer.log("JSON parsed successfully", name: "rubintv.workspace.load");

      Instrument newInstrument = Instrument.fromJson(json["instrument"]);
      developer.log("New instrument: ${newInstrument.name}, current: ${state.instrument?.name}",
          name: "rubintv.workspace.load");

      if (state.instrument?.name != newInstrument.name) {
        developer.log("Instrument mismatch - waiting for instrument load", name: "rubintv.workspace.load");
        emit(state.copyWith(
          status: WorkspaceStatus.loadingInstrument,
          pendingJson: json,
        ));
        WebSocketManager().sendMessage(LoadInstrumentAction(instrument: newInstrument.name).toJson());
      } else {
        developer.log("Instrument matches - building workspace directly", name: "rubintv.workspace.load");
        // Build new workspace from JSON
        _applyWorkspaceJsonWithClear(emit, json, state);
      }
    } catch (e, stackTrace) {
      developer.log("Error loading workspace: $e",
          name: "rubintv.workspace.load", error: e, stackTrace: stackTrace);
      emit(state.copyWith(status: WorkspaceStatus.error, errorMessage: "Failed to load workspace: $e"));
    }
  }

  Future<void> _applyWorkspaceJsonWithClear(
      Emitter<WorkspaceStateBase> emit, Map<String, dynamic> json, WorkspaceState currentState) async {
    developer.log("=== CLEARING BEFORE JSON LOAD ===", name: "rubintv.workspace.load");

    // 1. Clear the old workspace FIRST
    await _clearWorkspace(currentState, skipGlobalQueryReset: true);
    developer.log("Workspace cleared, now building from JSON", name: "rubintv.workspace.load");

    // 2. Build new workspace from JSON AFTER clearing
    WorkspaceState newState = WorkspaceState.fromJson(
      json,
      currentState.theme,
      currentState.version,
    );

    // 3. Continue with the rest of the application logic
    _applyWorkspaceJson(emit, newState);
  }

  /// Build a workspace from a JSON object.
  void _applyWorkspaceJson(Emitter<WorkspaceStateBase> emit, WorkspaceState newState) async {
    developer.log("=== APPLYING JSON WORKSPACE ===", name: "rubintv.workspace.load");
    developer.log("New state: windows=${newState.windows.length}, instrument=${newState.instrument?.name}",
        name: "rubintv.workspace.load");

    // First emit the new state so it's available everywhere
    if (!emit.isDone) {
      emit(newState);
      developer.log("New workspace state emitted", name: "rubintv.workspace.load");
    }

    String? dayObs = getFormattedDate(newState.dayObs);
    developer.log("DayObs for sync: $dayObs", name: "rubintv.workspace.load");

    // Use a flag to track whether the global query update was made, to avoid duplicate updates
    bool globalQueryUpdated = false;

    // Then sync data for all windows, but we don't need to trigger the global query stream
    // as the charts will get their data directly
    for (var window in newState.windows.values) {
      developer.log("Processing window ${window.id} of type ${window.windowType}",
          name: "rubintv.workspace.load");

      if (window.bloc is ChartBloc) {
        developer.log("Syncing ChartBloc data for window ${window.id} with dayObs=$dayObs",
            name: "rubintv.workspace.load");

        // Send direct SynchData event instead of going through global query stream
        (window.bloc as ChartBloc).add(SynchDataEvent(
          dayObs: dayObs,
          globalQuery: newState.globalQuery,
          skipGlobalUpdate: true, // Indicate this is a direct update without triggering global query
        ));

        if (!globalQueryUpdated) {
          developer.log("Updating global query (first time)", name: "rubintv.workspace.load");
          // Update global query only once, after the first window is processed
          ControlCenter().updateGlobalQuery(newState.getGlobalQuery());
          globalQueryUpdated = true;
        }
      } else if (window.bloc is FocalPlaneChartBloc) {
        developer.log("Syncing FocalPlaneChartBloc data for window ${window.id}",
            name: "rubintv.workspace.load");
        (window.bloc as FocalPlaneChartBloc).add(SynchDataEvent(
          dayObs: dayObs,
          globalQuery: newState.globalQuery,
        ));

        if (!globalQueryUpdated) {
          developer.log("Updating global query (first time - focal plane)", name: "rubintv.workspace.load");
          // Update global query only once, after the first window is processed
          ControlCenter().updateGlobalQuery(newState.getGlobalQuery());
          globalQueryUpdated = true;
        }
      }
    }

    developer.log("=== WORKSPACE LOAD COMPLETE ===", name: "rubintv.workspace.load");
  }

  /// Clear the workspace and the DataCenter.
  Future<void> _clearWorkspace(WorkspaceState state, {bool skipGlobalQueryReset = false}) async {
    developer.log("=== CLEARING WORKSPACE ===", name: "rubintv.workspace.clear");
    developer.log("Windows to close: ${state.windows.length}, skipGlobalQueryReset: $skipGlobalQueryReset",
        name: "rubintv.workspace.clear");

    // Close all of the windows and cancel their subscriptions.
    for (WindowMetaData window in state.windows.values) {
      if (window.windowType.isChart || window.windowType == WindowTypes.focalPlane) {
        developer.log("Closing window ${window.id} of type ${window.windowType}",
            name: "rubintv.workspace.clear");
        await window.bloc.close();
      }
    }
    developer.log("All window blocs closed", name: "rubintv.workspace.clear");

    if (skipGlobalQueryReset) {
      developer.log("Resetting selection controllers only", name: "rubintv.workspace.clear");
      ControlCenter().selectionController.reset();
      ControlCenter().drillDownController.reset();
    } else {
      developer.log("Full ControlCenter reset", name: "rubintv.workspace.clear");
      ControlCenter().reset();
    }

    // Clear the DataCenter Series Data.
    DataCenter().clearSeriesData();
    developer.log("DataCenter series data cleared", name: "rubintv.workspace.clear");
    developer.log("=== WORKSPACE CLEAR COMPLETE ===", name: "rubintv.workspace.clear");
  }

  /// Cancel the subscription to the websocket.
  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}

/// A class to represent the version of the application.
class AppVersion {
  /// The major version number.
  final int major;

  /// The minor version number.
  final int minor;

  /// The patch version number.
  final int patch;

  /// The build number.
  final String buildNumber;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.buildNumber,
  });

  /// Create an [AppVersion] from a string.
  static AppVersion fromString(String version, String buildNumber) {
    List<String> parts = version.split('.');
    if (parts.length != 3) throw Exception('Invalid version string: $version');

    return AppVersion(
      major: int.parse(parts[0]),
      minor: int.parse(parts[1]),
      patch: int.parse(parts[2]),
      buildNumber: buildNumber,
    );
  }

  @override
  String toString() => '$major.$minor.$patch';

  /// Create an [AppVersion] from a JSON object.
  static AppVersion fromJson(Map<String, dynamic> json) {
    return AppVersion(
      major: json["major"],
      minor: json["minor"],
      patch: json["patch"],
      buildNumber: json["buildNumber"],
    );
  }

  /// Convert the [AppVersion] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      "major": major,
      "minor": minor,
      "patch": patch,
      "buildNumber": buildNumber,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.buildNumber == buildNumber;

  @override
  int get hashCode => major.hashCode ^ minor.hashCode ^ patch.hashCode ^ buildNumber.hashCode;
}

/// Convert a workspace to the current version
Map<String, dynamic> convertWorkspace(Map<String, dynamic> json, AppTheme theme, AppVersion version) {
  // No changes have been made to the persistable workspace yet
  return json;
}
