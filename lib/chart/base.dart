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
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/binned.dart';
import 'package:rubintv_visualization/chart/scatter.dart';
import 'package:rubintv_visualization/editors/axis.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/error.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/primitives.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// Tools for selecting unique sources.
enum MultiSelectionTool {
  select(Icons.touch_app, CursorAction.select),
  drillDown(Icons.query_stats, CursorAction.drillDown),
  dateTimeSelect(Icons.calendar_month_outlined, CursorAction.dateTimeSelect),
  ;

  final IconData icon;
  final CursorAction cursorAction;

  const MultiSelectionTool(this.icon, this.cursorAction);

  /// Create a [MultiSelectionTool] from a string.
  /// Note, to go in the other direction juse use [tool.name],
  /// where tool is a [MultiSelectionTool].
  static MultiSelectionTool fromString(String value) => values.firstWhere((e) => e.toString() == value,
      orElse: () => throw ArgumentError("Unknown MultiSelectionTool: $value"));
}

abstract class ChartEvent extends WindowEvent {}

/// A message received via the websocket.
class ChartReceiveMessageEvent extends ChartEvent {
  final Map<String, dynamic> message;

  ChartReceiveMessageEvent(this.message);
}

/// Update the selection tool for a chart.
class UpdateMultiSelect extends ChartEvent {
  final MultiSelectionTool tool;

  UpdateMultiSelect(this.tool);
}

/// Update whether or not to use the global query for a chart.
class UpdateChartGlobalQueryEvent extends ChartEvent {
  final bool useGlobalQuery;
  final String? dayObs;
  final QueryExpression? globalQuery;

  UpdateChartGlobalQueryEvent({
    required this.useGlobalQuery,
    required this.dayObs,
    required this.globalQuery,
  });
}

/// Update a [Series] in a chart.
class UpdateSeriesEvent extends ChartEvent {
  final SeriesInfo series;
  final String? dayObs;
  final QueryExpression? globalQuery;
  final SchemaField? groupByColumn;

  UpdateSeriesEvent({
    required this.series,
    required this.dayObs,
    required this.globalQuery,
    this.groupByColumn,
  });
}

/// Update the number of bins in a binned chart.
class UpdateBinsEvent extends ChartEvent {
  final int nBins;

  UpdateBinsEvent(this.nBins);
}

/// Update the [ChartAxisInfo] for a chart.
class UpdateAxisInfoEvent extends ChartEvent {
  final ChartAxisInfo axisInfo;

  UpdateAxisInfoEvent(this.axisInfo);
}

/// Reset the chart.
class ResetChartEvent extends ChartEvent {
  final ChartResetTypes type;
  ResetChartEvent(this.type);
}

/// Reload all of the data from the server
class SynchDataEvent extends ChartEvent {
  final String? dayObs;
  final QueryExpression? globalQuery;

  SynchDataEvent({
    required this.dayObs,
    required this.globalQuery,
  });
}

class DeleteSeriesEvent extends ChartEvent {
  final SeriesId seriesId;

  DeleteSeriesEvent(this.seriesId);
}

/// Persistable information to generate a chart
class ChartState extends WindowState {
  /// The series that are plotted on the chart.
  final Map<SeriesId, SeriesInfo> _series;

  /// The legend displayed on the chart.
  final Legend? legend;

  /// Information about the chart axes.
  final List<ChartAxisInfo> _axisInfo;

  /// Whether or not to use the global query for all series in this [ChartLoadedState].
  final bool useGlobalQuery;

  /// The selection tool to use for this chart.
  final MultiSelectionTool tool;

  /// A controller for resetting the chart.
  /// This is required since rubin_chart keeps parameters like the axis bounds
  /// and the data plots plotted hidden in the state and it doesn't always
  /// know when to reset them.
  final StreamController<ResetChartAction> resetController;

  /// Whether or not this chart needs a reset.
  bool needsReset;

  ChartState({
    required super.id,
    required super.windowType,
    required Map<SeriesId, SeriesInfo> series,
    required List<ChartAxisInfo> axisInfo,
    required this.legend,
    required this.useGlobalQuery,
    required this.tool,
    required this.resetController,
    this.needsReset = false,
  })  : _series = Map<SeriesId, SeriesInfo>.unmodifiable(series),
        _axisInfo = List<ChartAxisInfo>.unmodifiable(axisInfo);

  /// Whether or not to use a selection controller.
  bool get useSelectionController => tool == MultiSelectionTool.select;

  /// Whether or not to use a drill down controller.
  bool get useDrillDownController => tool == MultiSelectionTool.drillDown;

  /// Return a copy of the internal [Map] of [SeriesInfo], to prevent updates.
  Map<SeriesId, SeriesInfo> get series => {..._series};

  /// Return a copy of the internal [List] of [ChartAxisInfo], to prevent updates.
  List<ChartAxisInfo> get axisInfo => [..._axisInfo];

  /// Make a copy of this [ChartState] with the given parameters updated.
  ChartState copyWith({
    UniqueId? id,
    Map<SeriesId, SeriesInfo>? series,
    List<ChartAxisInfo>? axisInfo,
    Legend? legend,
    bool? useGlobalQuery,
    WindowTypes? windowType,
    MultiSelectionTool? tool,
    StreamController<ResetChartAction>? resetController,
    bool? needsReset,
  }) =>
      ChartState(
        id: id ?? this.id,
        series: series ?? _series,
        axisInfo: axisInfo ?? _axisInfo,
        legend: legend ?? this.legend,
        useGlobalQuery: useGlobalQuery ?? this.useGlobalQuery,
        windowType: windowType ?? this.windowType,
        tool: tool ?? this.tool,
        resetController: resetController ?? this.resetController,
        needsReset: needsReset ?? false,
      );

  /// Whether or not at least one [PlotAxis] has been set.
  bool get hasAxes => axisInfo.isNotEmpty;

  /// Whether or not at least one [Series] has been initialized.
  bool get hasSeries => _series.isNotEmpty;

  /// Get a list of all of the [Series] in the chart.
  List<Series> get allSeries {
    List<Series> allSeries = [];
    for (SeriesInfo seriesInfo in _series.values) {
      Series series = seriesInfo.toSeries();
      allSeries.add(series);
    }
    return allSeries;
  }

  /// Convert the [ChartState] to a JSON object.
  @override
  Map<String, dynamic> toJson() {
    return {
      "id": id.toSerializableString(),
      "series": _series.values.map((e) => e.toJson()).toList(),
      "axisInfo": _axisInfo.map((e) => e.toJson()).toList(),
      "legend": legend?.toJson(),
      "useGlobalQuery": useGlobalQuery,
      "windowType": windowType.name,
      "tool": tool.toString(),
    };
  }

  /// Create a [ChartState] from a JSON object.
  @override
  factory ChartState.fromJson(Map<String, dynamic> json) {
    return ChartState(
      id: UniqueId.fromString(json["id"]),
      series: Map.fromEntries((json["series"] as List<dynamic>).map((e) {
        SeriesInfo seriesInfo = SeriesInfo.fromJson(e);
        return MapEntry(seriesInfo.id, seriesInfo);
      })),
      axisInfo: List<ChartAxisInfo>.from(json["axisInfo"].map((e) => ChartAxisInfo.fromJson(e))),
      legend: json["legend"] == null ? null : Legend.fromJson(json["legend"]),
      useGlobalQuery: json["useGlobalQuery"],
      windowType: WindowTypes.fromString(json["windowType"]),
      tool: MultiSelectionTool.fromString(json["tool"]),
      resetController: StreamController<ResetChartAction>.broadcast(),
    );
  }
}

/// The base class for all chart blocs.
class ChartBloc extends WindowBloc<ChartState> {
  /// Subscription to the websocket.
  late StreamSubscription _subscription;

  /// Subscription to changes in the global query or global dayObs values.
  late StreamSubscription _globalQuerySubscription;

  ChartBloc(super.initialState) {
    /// Listen for messages from the websocket.
    _subscription = WebSocketManager().messages.listen((message) {
      add(ChartReceiveMessageEvent(message));
    });

    /// Reload the data if the global query or global dayObs changes.
    _globalQuerySubscription = ControlCenter().globalQueryStream.listen((GlobalQuery? query) {
      for (SeriesInfo series in state._series.values) {
        add(UpdateSeriesEvent(
          series: series,
          globalQuery: query?.query,
          dayObs: query?.dayObs,
        ));
      }
    });

    /// A message is received from the websocket.
    on<ChartReceiveMessageEvent>((event, emit) {
      //developer.log("received message: ${event.message.keys}, requestId: ${event.message['requestId']}",
      //    name: "rubin_chart.workspace");
      List<String>? splitId = event.message["requestId"]?.split(",");
      if (splitId == null || splitId.length != 2) {
        return;
      }
      UniqueId windowId = UniqueId.fromString(splitId[0]);
      SeriesId seriesId = SeriesId.fromString(splitId[1]);

      if (event.message["type"] == "table columns" && windowId == state.id) {
        // Process the results of a LoadColumnsCommand.
        int rows = event.message["content"]["data"].values.first.length;
        int columns = event.message["content"]["data"].length;
        developer.log(
            "received $columns columns and $rows rows for ${event.message["requestId"]} in series $seriesId",
            name: "rubin_chart.workspace");
        DataCenter().updateSeriesData(
          series: state.series[seriesId]!,
          dataSourceName: event.message["content"]["schema"],
          plotColumns: List<String>.from(event.message["content"]["columns"].map((e) => e)),
          data: Map<String, List<dynamic>>.from(
              event.message["content"]["data"].map((key, value) => MapEntry(key, List<dynamic>.from(value)))),
        );
      }
      emit(state.copyWith());
    });

    /// Initialize a scatter plot.
    on<InitializeScatterPlotEvent>((event, emit) {
      emit(ChartState(
        id: event.id,
        series: {},
        axisInfo: event.axisInfo,
        legend: Legend(),
        useGlobalQuery: true,
        windowType: event.chartType,
        tool: MultiSelectionTool.select,
        resetController: StreamController<ResetChartAction>.broadcast(),
      ));
    });

    /// Initialize a binned chart.
    on<InitializeBinnedEvent>((event, emit) {
      emit(BinnedState(
        id: event.id,
        series: {},
        axisInfo: event.axisInfo,
        legend: Legend(),
        useGlobalQuery: true,
        windowType: event.chartType,
        tool: MultiSelectionTool.select,
        nBins: 20,
        resetController: StreamController<ResetChartAction>.broadcast(),
      ));
    });

    /// Change the selection tool.
    on<UpdateMultiSelect>((event, emit) {
      emit(state.copyWith(tool: event.tool));
    });

    /// Toggle the use of the global query in this Chart.
    on<UpdateChartGlobalQueryEvent>((event, emit) {
      emit(state.copyWith(useGlobalQuery: event.useGlobalQuery));
      for (SeriesInfo series in state._series.values) {
        _fetchSeriesData(
          series: series,
          dayObs: event.dayObs,
          globalQuery: event.globalQuery,
        );
      }
    });

    /// A Series in the chart is updated. This will trigger a reload of the data from the remote server.
    on<UpdateSeriesEvent>((event, emit) {
      if (event.groupByColumn != null) {
        throw UnimplementedError("Group by column not yet implemented");
      } else {
        // Update the series
        Map<SeriesId, SeriesInfo> newSeries = {...state._series};
        newSeries[event.series.id] = event.series;

        // Update the axis labels, if necessary
        List<ChartAxisInfo> axesInfo = state.axisInfo;
        for (int i = 0; i < axesInfo.length; i++) {
          ChartAxisInfo axisInfo = axesInfo[i];
          // Axis labels are surrounded by <> to indicate that they have not been set yet.
          if ((axisInfo.label.startsWith("<") && axisInfo.label.endsWith(">")) || state._series.length == 1) {
            axesInfo[i] = axisInfo.copyWith(label: event.series.fields.values.toList()[i].name);
          }
        }
        emit(state.copyWith(series: newSeries, axisInfo: axesInfo));
      }
      // Load the data from the server.
      _fetchSeriesData(
        series: event.series,
        globalQuery: event.globalQuery,
        dayObs: event.dayObs,
      );
    });

    /// Update the number of bins for a binned chart.
    on<UpdateBinsEvent>((event, emit) {
      BinnedState state = this.state as BinnedState;
      emit(state.copyWith(nBins: event.nBins));
    });

    /// Update the axis information for a chart.
    on<UpdateAxisInfoEvent>((event, emit) {
      List<ChartAxisInfo> newAxisInfo = state.axisInfo.map((ChartAxisInfo info) {
        if (info.axisId == event.axisInfo.axisId) {
          return event.axisInfo;
        }
        return info;
      }).toList();
      emit(state.copyWith(axisInfo: newAxisInfo, needsReset: true));
    });

    /// Reset the chart.
    on<ResetChartEvent>((event, emit) {
      state.resetController.add(ResetChartAction(event.type));
      emit(state.copyWith(needsReset: false));
    });

    /// Reload all of the data from the server.
    on<SynchDataEvent>((event, emit) {
      for (SeriesInfo series in state._series.values) {
        developer.log("Synching data for series ${series.id}", name: "rubintv.chart.base.dart");
        _fetchSeriesData(
          series: series,
          globalQuery: event.globalQuery,
          dayObs: event.dayObs,
        );
        developer.log("synch request sent", name: "rubintv.chart.base.dart");
      }
    });

    on<DeleteSeriesEvent>((event, emit) {
      Map<SeriesId, SeriesInfo> newSeries = {...state._series};
      newSeries.remove(event.seriesId);
      DataCenter().removeSeriesData(event.seriesId);
      emit(state.copyWith(series: newSeries));
    });
  }

  /// Request data from the server for a series.
  void _fetchSeriesData({
    required SeriesInfo series,
    required String? dayObs,
    required QueryExpression? globalQuery,
  }) {
    WebSocketManager websocket = WebSocketManager();
    if (websocket.isConnected) {
      websocket.sendMessage(LoadColumnsCommand.build(
        seriesId: series.id,
        fields: series.fields.values.toList(),
        query: series.query,
        globalQuery: globalQuery,
        useGlobalQuery: state.useGlobalQuery,
        dayObs: dayObs,
        windowId: state.id,
      ).toJson());
    }
  }

  /// Check if a series is compatible with this chart.
  /// Any mismatched columns have their indices returned.
  List<AxisId>? canAddSeries({
    required SeriesInfo series,
    required DataCenter dataCenter,
  }) {
    final List<AxisId> mismatched = [];
    // Check that the series has the correct number of columns and axes
    if (series.fields.length != state.axisInfo.length) {
      developer.log("bad axes", name: "rubin_chart.core.chart.dart");
      return null;
    }
    for (AxisId sid in series.fields.keys) {
      SchemaField field = series.fields[sid]!;
      for (SeriesInfo otherSeries in state._series.values) {
        SchemaField? otherField = otherSeries.fields[sid];
        if (otherField == null) {
          developer.log("missing field $sid", name: "rubin_chart.core.chart.dart");
          mismatched.add(sid);
        } else {
          // Check that the new series is compatible with the existing series
          if (!dataCenter.isFieldCompatible(field, otherField)) {
            developer.log(
              "Incompatible fields $otherField and $field",
              name: "rubin_chart.core.chart.dart",
            );
            mismatched.add(sid);
          }
        }
      }
    }
    return mismatched;
  }

  /// Get the next series ID for this [ChartLoadedState].
  BigInt get nextSeriesId {
    BigInt maxId = BigInt.zero;
    for (SeriesId sid in state._series.keys) {
      if (sid.id > maxId) {
        maxId = sid.id;
      }
    }
    return maxId + BigInt.one;
  }

  /// Create a new empty Series for this [ChartLoadedState].
  SeriesInfo nextSeries() {
    try {
      SeriesId sid = SeriesId(windowId: state.id, id: nextSeriesId);
      DatabaseSchema database = DataCenter().databases.values.first;
      TableSchema table = database.tables.values.first;
      Map<AxisId, SchemaField> fields = {};
      for (int i = 0; i < state.axisInfo.length; i++) {
        fields[state.axisInfo[i].axisId] = table.fields.values.toList()[i];
      }
      return SeriesInfo(
        id: sid,
        name: "Series-${state.id.id}",
        axes: state.axisInfo.map((ChartAxisInfo? info) => info!.axisId).toList(),
        fields: fields,
      );
    } catch (e) {
      reportError("Error creating new series: $e");
      rethrow;
    }
  }

  /// Get the maximum number of axes for this chart.
  int get nMaxAxes {
    if (state.windowType == WindowTypes.histogram) {
      return 1;
    } else if (state.windowType == WindowTypes.cartesianScatter) {
      return 2;
    } else if (state.windowType == WindowTypes.polarScatter) {
      return 2;
    } else if (state.windowType == WindowTypes.combination) {
      return 2;
    }
    throw UnimplementedError("Unknown chart type: ${state.windowType}");
  }

  /// Open the [SeriesEditor] dialog to edit a series.
  Future<void> _editSeries(BuildContext context, SeriesInfo series) async {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    if (workspace.info?.instrument?.schema == null) {
      throw ArgumentError("The chosen instrument has no schema");
    }
    developer.log("New series fields: ${series.fields}", name: "rubin_chart.core.chart.dart");
    return showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: SeriesEditor(
          theme: workspace.theme,
          series: series,
          workspace: workspace,
          chartBloc: this,
          databaseSchema: DataCenter().databases[workspace.info!.instrument!.schema]!,
        ),
      ),
    );
  }

  /// The action to perform when a [Series] entry in a chart [Legend] is selected.
  /// This will open the [SeriesEditor] dialog to edit the series.
  void onLegendSelect({required Series series, required BuildContext context}) {
    bool found = false;
    for (SeriesId seriesId in state.series.keys) {
      if (seriesId == series.id) {
        _editSeries(context, state.series[seriesId]!);
        found = true;
      }
    }
    if (!found) {
      throw ArgumentError("Series ${series.id} not found in chart with series ${state.series.keys}");
    }
  }

  /// The action to perform when an [Axis] entry in a chart [Legend] is selected.
  /// This will open the [AxisEditor] dialog to edit the axis properties.
  void onAxisTap({required AxisId axisId, required BuildContext context}) {
    for (ChartAxisInfo axisInfo in state.axisInfo) {
      if (axisInfo.axisId == axisId) {
        // Open the field editor
        showDialog(
          context: context,
          builder: (BuildContext context) => Dialog(
            child: AxisEditor(
              axisInfo: axisInfo,
              chartBloc: this,
            ),
          ),
        );
        return;
      }
    }
    throw ArgumentError("Axis not found in chart");
  }

  /// Get the default widgets for the toolbar of all charts.
  List<Widget> getDefaultTools(BuildContext context) {
    bool useGlobalQuery = state.useGlobalQuery;
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return [
      Tooltip(
        message: "Add a new series to the chart",
        child: IconButton(
          icon: const Icon(Icons.format_list_bulleted_add, color: Colors.green),
          onPressed: () {
            SeriesInfo newSeries = nextSeries();
            _editSeries(context, newSeries);
          },
        ),
      ),
      Tooltip(
        message: "Use the global query",
        child: IconButton(
          icon: useGlobalQuery
              ? const Icon(Icons.travel_explore, color: Colors.green)
              : const Icon(Icons.public_off, color: Colors.grey),
          onPressed: () {
            context.read<ChartBloc>().add(UpdateChartGlobalQueryEvent(
                  useGlobalQuery: !useGlobalQuery,
                  dayObs: getFormattedDate(workspace.info!.dayObs),
                  globalQuery: workspace.info!.globalQuery,
                ));
          },
        ),
      ),
      const SizedBox(width: 10),
      Tooltip(
        message: "Reset the chart axes",
        child: IconButton(
          icon: const Icon(Icons.refresh, color: Colors.green),
          onPressed: () {
            state.resetController.add(ResetChartAction(ChartResetTypes.full));
          },
        ),
      ),
      Tooltip(
        message: "Synch chart data with the server",
        child: IconButton(
          icon: const Icon(Icons.sync, color: Colors.green),
          onPressed: () {
            context.read<ChartBloc>().add(SynchDataEvent(
                  dayObs: getFormattedDate(workspace.info!.dayObs),
                  globalQuery: workspace.info!.globalQuery,
                ));
          },
        ),
      ),
      const SizedBox(width: 10),
      Container(
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
        child: Tooltip(
          message: "Remove chart",
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              // Clear the window in the workspace
              context.read<WorkspaceBloc>().add(RemoveWindowEvent(state.id));
              // Remove all of the series in the chart from the DataCenter.
              for (SeriesInfo series in state._series.values) {
                DataCenter().removeSeriesData(series.id);
              }
            },
          ),
        ),
      )
    ];
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _globalQuerySubscription.cancel();
    return super.close();
  }
}
