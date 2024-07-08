import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/focal_plane/instrument.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class GlobalQuery {
  final Query? query;
  final String? dayObs;
  final Instrument? instrument;
  final Detector? detector;

  GlobalQuery({
    required this.query,
    required this.dayObs,
    required this.instrument,
    required this.detector,
  });
}

abstract class WorkspaceEvent {}

class InitializeWorkspaceEvent extends WorkspaceEvent {
  final AppTheme theme;

  InitializeWorkspaceEvent(this.theme);
}

/// A message received via the websocket.
class ReceiveMessageEvent extends WorkspaceEvent {
  final Map<String, dynamic> message;

  ReceiveMessageEvent(this.message);
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
  final DateTime? dayObs;

  UpdateGlobalObsDateEvent({required this.dayObs});
}

/// Add a new [CartesianPlot] to the [WorkspaceViewer].
class CreateNewWindowEvent extends WorkspaceEvent {
  final WindowTypes windowType;

  CreateNewWindowEvent({
    this.windowType = WindowTypes.cartesianScatter,
  });
}

class ShowFocalPlaneEvent extends WorkspaceEvent {
  ShowFocalPlaneEvent();
}

/// State of a [WorkspaceViewer].
abstract class WorkspaceStateBase {
  const WorkspaceStateBase();
}

/// The initial state of the [WorkspaceViewer].
class WorkspaceStateInitial extends WorkspaceStateBase {}

/// A fully loaded state of the [WorkspaceViewer].
class WorkspaceState extends WorkspaceStateBase {
  /// Windows to display in the [WorkspaceState].
  final Map<UniqueId, Window> windows;

  /// A query that applies to all plots (that opt in to gloabl queries)
  final Query? globalQuery;

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

  @override
  String toString() {
    return "WorkspaceStateLoaded(windows: $windows, instrument: $instrument, globalQuery: $globalQuery, "
        "dayObs: $dayObs, detector: $detector, theme: $theme, interactionInfo: $interactionInfo)";
  }

  const WorkspaceState({
    required this.windows,
    required this.instrument,
    required this.globalQuery,
    required this.dayObs,
    required this.detector,
    required this.theme,
    required this.interactionInfo,
  });

  /// Copy the [WorkspaceState] with new values.
  WorkspaceState copyWith({
    Map<UniqueId, Window>? windows,
    Instrument? instrument,
    Detector? detector,
    bool? showFocalPlane,
    AppTheme? theme,
  }) =>
      WorkspaceState(
          windows: windows ?? this.windows,
          globalQuery: globalQuery,
          dayObs: dayObs,
          instrument: instrument ?? this.instrument,
          detector: detector ?? this.detector,
          theme: theme ?? this.theme,
          interactionInfo: interactionInfo);

  /// Because the global query can be null, we need a special copy method.
  WorkspaceState updateGlobalQuery(Query? query) => WorkspaceState(
        windows: windows,
        instrument: instrument,
        globalQuery: query,
        dayObs: dayObs,
        detector: detector,
        theme: theme,
        interactionInfo: interactionInfo,
      );

  /// Becayse the dayObs can be null, we need a special copy method.
  WorkspaceState updateObsDate(DateTime? dayObs) => WorkspaceState(
      windows: windows,
      instrument: instrument,
      globalQuery: globalQuery,
      dayObs: dayObs,
      detector: detector,
      theme: theme,
      interactionInfo: interactionInfo);

  // Because the detector can be null, we need a special copy method.
  WorkspaceState updateSelectedDetector(Detector? detector) => WorkspaceState(
      windows: windows,
      instrument: instrument,
      globalQuery: globalQuery,
      dayObs: dayObs,
      detector: detector,
      theme: theme,
      interactionInfo: interactionInfo);

  WorkspaceState updateInteractionInfo(WindowInteractionInfo? interactionInfo) => WorkspaceState(
      windows: windows,
      instrument: instrument,
      globalQuery: globalQuery,
      dayObs: dayObs,
      detector: detector,
      theme: theme,
      interactionInfo: interactionInfo);

  /// Add a new [Window] to the [WorkspaceWidgetState].
  /// Normally the [index] is already created, unless
  /// the workspace is being loaded from disk.
  WorkspaceState addWindow(Window window) {
    Map<UniqueId, Window> newWindows = {...windows};
    newWindows[window.id] = window;

    return copyWith(
      windows: newWindows,
    );
  }

  /// Whether or not the window is showing the focal plane.
  bool get isShowingFocalPlane => windows.values.any((window) => window.type == WindowTypes.detectorSelector);

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
void updateAllSeriesData(WorkspaceState workspace, {ChartStateLoaded? chart}) {
  String? dayObs = getFormattedDate(workspace.dayObs);

  late final List<ChartStateLoaded> charts;
  if (chart != null) {
    charts = [chart];
  } else {
    charts = workspace.windows.values.whereType<ChartStateLoaded>().toList();
    developer.log("Updating all series data for ${charts.length} charts", name: "rubin_chart.workspace");
  }
  // Request the data from the server.
  if (WebSocketManager().isConnected) {
    for (ChartStateLoaded chart in charts) {
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

  WorkspaceBloc() : super(WorkspaceStateInitial()) {
    /// Listen for messages from the websocket.
    _subscription = WebSocketManager().messages.listen((message) {
      add(ReceiveMessageEvent(message));
    });

    on<InitializeWorkspaceEvent>((event, emit) {
      emit(WorkspaceState(
        windows: {},
        instrument: null,
        globalQuery: null,
        dayObs: null,
        detector: null,
        theme: event.theme,
        interactionInfo: null,
      ));
    });

    /// A message is received from the websocket.
    on<ReceiveMessageEvent>((event, emit) {
      developer.log("Workspace Received message: ${event.message["type"]}", name: "rubin_chart.workspace");
      if (event.message["type"] == "instrument info") {
        // Update the workspace to use the new instrument
        Instrument instrument = Instrument.fromJson(event.message["content"]);
        emit((state as WorkspaceState).copyWith(instrument: instrument));
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
      developer.log("updating date to ${event.dayObs}!", name: "rubin_chart.workspace");
      WorkspaceState state = this.state as WorkspaceState;
      state = state.updateObsDate(event.dayObs);
      ControlCenter().updateGlobalQuery(state.getGlobalQuery());
      emit(state);
    });

    /// Create a new chart
    on<CreateNewWindowEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      Offset offset = state.theme.newWindowOffset;

      if (state.windows.isNotEmpty) {
        // Shift from last window
        offset += state.windows.values.last.offset;
      }

      Window newWindow = Window(
        id: UniqueId.next(),
        offset: offset,
        size: state.theme.newPlotSize,
        type: event.windowType,
      );
      Map<UniqueId, Window> windows = {...state.windows};
      windows[newWindow.id] = newWindow;
      emit(state.copyWith(windows: windows));
    });

    /// Add a new window with the FocalPlane displayed.
    on<ShowFocalPlaneEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;

      // Make sure that the focal plane isn't already opened
      for (Window window in state.windows.values) {
        if (window.type == WindowTypes.detectorSelector) {
          return;
        }
      }

      Offset offset = state.theme.newWindowOffset;
      if (state.windows.isNotEmpty) {
        // Shift from last window
        offset += state.windows.values.last.offset;
      }

      Window newWindow = Window(
        id: UniqueId.next(),
        offset: offset,
        size: state.theme.newPlotSize,
        type: WindowTypes.detectorSelector,
      );
      Map<UniqueId, Window> windows = {...state.windows};
      windows[newWindow.id] = newWindow;

      developer.log("Added new focal plane window: $newWindow", name: "rubin_chart.workspace");

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
      Map<UniqueId, Window> windows = {...state.windows};
      windows.remove(event.windowId);
      emit(state.copyWith(windows: windows));
    });

    /// Keep track of the starting drag position
    on<WindowDragStartEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      if (state.interactionInfo != null) {
        state = state.updateInteractionInfo(null);
      }
      Window window = state.windows[event.windowId]!;
      WindowInteractionInfo interactionInfo = WindowDragInfo(
        id: event.windowId,
        pointerOffset: window.offset - event.details.localPosition,
      );
      emit(state.updateInteractionInfo(interactionInfo));
    });

    on<WindowDragUpdate>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      if (state.interactionInfo is! WindowDragInfo) {
        state = state.updateInteractionInfo(null);
        throw Exception("Mismatched interactionInfo, got ${state.interactionInfo}");
      }
      Map<UniqueId, Window> windows = {...state.windows};
      Window window = windows[event.windowId]!;
      Offset offset = event.details.localPosition + (state.interactionInfo as WindowDragInfo).pointerOffset;
      window = window.copyWith(offset: offset);
      windows[event.windowId] = window;
      emit(state.copyWith(windows: windows));
    });
    on<WindowDragEndEvent>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      emit(state.updateInteractionInfo(null));
    });

    on<StartWindowResize>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      if (state.interactionInfo != null) {
        state = state.updateInteractionInfo(null);
      }
      Window window = state.windows[event.windowId]!;
      WindowInteractionInfo interactionInfo = WindowResizeInfo(
        id: event.windowId,
        initialPointerOffset: event.details.globalPosition,
        initialSize: window.size,
        initialOffset: window.offset,
      );
      emit(state.updateInteractionInfo(interactionInfo));
    });

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
      Map<UniqueId, Window> windows = {...state.windows};
      Window window = windows[event.windowId]!;
      window = window.copyWith(
        size: size,
        offset: offset,
      );
      windows[event.windowId] = window;
      emit(state.copyWith(windows: windows));
    });

    on<EndWindowResize>((event, emit) {
      WorkspaceState state = this.state as WorkspaceState;
      emit(state.updateInteractionInfo(null));
    });
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
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
