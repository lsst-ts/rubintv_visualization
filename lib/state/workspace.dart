import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/time_machine.dart';
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
  /// The key is name of the [DataSet] containing the point, and the [Set] is the
  /// set of keys in that [DataSet] that are selected.
  final Map<String, Set<dynamic>> _selected;

  /// Which tool to use for multi-selection/zoom
  final MultiSelectionTool multiSelectionTool;

  const Workspace({
    required this.theme,
    Map<int, Window> windows = const {},
    Map<String, Set<dynamic>> selected = const {},
    this.multiSelectionTool = MultiSelectionTool.select,
  })  : _windows = windows,
        _selected = selected;

  Workspace copyWith({
    ChartTheme? theme,
    Map<int, Window>? windows,
    Map<String, Set<dynamic>>? selected,
    MultiSelectionTool? multiSelectionTool,
  }) =>
      Workspace(
        theme: theme ?? this.theme,
        windows: windows ?? this.windows,
        selected: selected ?? this.selected,
        multiSelectionTool: multiSelectionTool ?? this.multiSelectionTool,
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
  /*TypedReducer<TimeMachine<Workspace>, NewCartesianPlotAction>(
      newCartesianPlotReducer),
  TypedReducer<TimeMachine<Workspace>, SeriesUpdateAction>(updateSeriesReducer),
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
