import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/series.dart';
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
}

abstract class ChartEvent {}

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

/// Update the number of bins for a chart.
class UpdateChartBinsAction extends ChartEvent {
  final int nBins;

  UpdateChartBinsAction({
    required this.nBins,
  });
}

/// Update whether or not to use the global query for a chart.
class UpdateChartGlobalQueryEvent extends ChartEvent {
  final bool useGlobalQuery;

  UpdateChartGlobalQueryEvent({
    required this.useGlobalQuery,
  });
}

/// Add a new [Series] to a chart.
class CreateSeriesAction extends ChartEvent {
  final SeriesInfo series;

  CreateSeriesAction({
    required this.series,
  });
}

abstract class ChartState {}

class ChartStateInitial extends ChartState {}

/// Persistable information to generate a chart
abstract class ChartStateLoaded extends ChartState {
  final UniqueId id;
  final GlobalKey key;
  final Map<SeriesId, SeriesInfo> _series;
  final Legend? legend;
  final List<ChartAxisInfo> _axisInfo;

  /// Whether or not to use the global query for all series in this [ChartLoadedState].
  final bool useGlobalQuery;

  final List<GlobalKey> childKeys;

  final DataCenter dataCenter;

  final WindowTypes chartType;

  final MultiSelectionTool tool;

  ChartStateLoaded({
    required this.key,
    required this.id,
    required Map<SeriesId, SeriesInfo> series,
    required List<ChartAxisInfo> axisInfo,
    required this.legend,
    required this.useGlobalQuery,
    required this.childKeys,
    required this.dataCenter,
    required this.chartType,
    required this.tool,
  })  : _series = Map<SeriesId, SeriesInfo>.unmodifiable(series),
        _axisInfo = List<ChartAxisInfo>.unmodifiable(axisInfo);

  bool get useSelectionController => tool == MultiSelectionTool.select;

  bool get useDrillDownController => tool == MultiSelectionTool.drillDown;

  /// Return a copy of the internal [Map] of [SeriesInfo], to prevent updates.
  Map<SeriesId, SeriesInfo> get series => {..._series};

  /// Return a copy of the internal [List] of [ChartAxisInfo], to prevent updates.
  List<ChartAxisInfo> get axisInfo => [..._axisInfo];

  ChartStateLoaded copyWith({
    UniqueId? id,
    Map<SeriesId, SeriesInfo>? series,
    List<ChartAxisInfo>? axisInfo,
    Legend? legend,
    bool? useGlobalQuery,
    List<GlobalKey>? childKeys,
    WindowTypes? chartType,
    MultiSelectionTool? tool,
  });

  /// Whether or not at least one [PlotAxis] has been set.
  bool get hasAxes => axisInfo.isNotEmpty;

  /// Whether or not at least one [Series] has been initialized.
  bool get hasSeries => _series.isNotEmpty;

  List<Series> get allSeries {
    List<Series> allSeries = [];
    for (SeriesInfo seriesInfo in _series.values) {
      Series? series = seriesInfo.toSeries(dataCenter);
      if (series != null) {
        allSeries.add(series);
      }
    }
    return allSeries;
  }
}

abstract class ChartBloc extends Bloc<ChartEvent, ChartState> {
  ChartBloc() : super(ChartStateInitial());

  onReceiveMesssage(ChartReceiveMessageEvent event, Emitter<ChartState> emit) {
    if (this.state is ChartStateInitial) {
      return;
    }
    ChartStateLoaded state = this.state as ChartStateLoaded;
    if (event.message["type"] == "table columns" && event.message["to"] == state.id) {
      developer.log(
          "received ${event.message["content"]["data"].length} columns for ${event.message["requestId"]}",
          name: "rubin_chart.workspace");
      SeriesId seriesId = SeriesId.fromString(event.message["requestId"] as String);
      state.dataCenter.updateSeriesData(
        series: state.series[seriesId]!,
        dataSourceName: event.message["content"]["schema"],
        plotColumns: List<String>.from(event.message["content"]["columns"].map((e) => e)),
        data: Map<String, List<dynamic>>.from(
            event.message["content"]["data"].map((key, value) => MapEntry(key, List<dynamic>.from(value)))),
      );
      developer.log("dataCenter data: ${state.dataCenter.seriesIds}", name: "rubin_chart.workspace");
    }
  }

  /// Check if a series is compatible with this chart.
  /// Any mismatched columns have their indices returned.
  List<AxisId>? canAddSeries({
    required SeriesInfo series,
    required DataCenter dataCenter,
  }) {
    ChartStateLoaded state = this.state as ChartStateLoaded;

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

  /// Update [ChartLoadedState] when [Series] is updated.
  ChartStateLoaded addSeries({
    required SeriesInfo series,
  }) {
    ChartStateLoaded state = this.state as ChartStateLoaded;

    Map<SeriesId, SeriesInfo> newSeries = {...state._series};
    newSeries[series.id] = series;
    return state.copyWith(series: newSeries);
  }

  BigInt get nextSeriesId {
    ChartStateLoaded state = this.state as ChartStateLoaded;

    BigInt maxId = BigInt.zero;
    for (SeriesId sid in state._series.keys) {
      if (sid.id > maxId) {
        maxId = sid.id;
      }
    }
    return maxId + BigInt.one;
  }

  /// Create a new empty Series for this [ChartLoadedState].
  SeriesInfo nextSeries({required DataCenter dataCenter}) {
    ChartStateLoaded state = this.state as ChartStateLoaded;

    SeriesId sid = SeriesId(windowId: state.id, id: nextSeriesId);
    DatabaseSchema database = dataCenter.databases.values.first;
    TableSchema table = database.tables.values.first;
    Map<AxisId, SchemaField> fields = {};
    for (int i = 0; i < state.axisInfo.length; i++) {
      fields[state.axisInfo[i]!.axisId] = table.fields.values.toList()[i];
    }
    return SeriesInfo(
      id: sid,
      name: "Series-${state.id.id}",
      axes: state.axisInfo.map((ChartAxisInfo? info) => info!.axisId).toList(),
      fields: fields,
    );
  }

  int get nMaxAxes {
    ChartStateLoaded state = this.state as ChartStateLoaded;
    if (state.chartType == WindowTypes.histogram) {
      return 1;
    } else if (state.chartType == WindowTypes.cartesianScatter) {
      return 2;
    } else if (state.chartType == WindowTypes.polarScatter) {
      return 2;
    } else if (state.chartType == WindowTypes.combination) {
      return 2;
    }
    throw UnimplementedError("Unknown chart type: ${state.chartType}");
  }

  Future<void> _editSeries(BuildContext context, SeriesInfo series, isNew) async {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: SeriesEditor(
          theme: workspace.theme,
          series: series,
          isNew: isNew,
          dataCenter: workspace.dataCenter,
        ),
      ),
    );
  }

  List<Widget> getDefaultTools(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    ChartStateLoaded state = this.state as ChartStateLoaded;
    return [
      Tooltip(
        message: "Add a new series to the chart",
        child: IconButton(
          icon: const Icon(Icons.format_list_bulleted_add, color: Colors.green),
          onPressed: () {
            SeriesInfo newSeries = nextSeries(dataCenter: workspace.dataCenter);
            context.read<ChartBloc>().add(CreateSeriesAction(series: newSeries));
            _editSeries(context, newSeries, true);
          },
        ),
      ),
      Tooltip(
        message: "Use the global query",
        child: IconButton(
          icon: state.useGlobalQuery
              ? const Icon(Icons.travel_explore, color: Colors.green)
              : const Icon(Icons.public_off, color: Colors.grey),
          onPressed: () {
            context.read<ChartBloc>().add(UpdateChartGlobalQueryEvent(
                  useGlobalQuery: !state.useGlobalQuery,
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
              context.read<WorkspaceBloc>().add(RemoveWindowAction(state.id));
            },
          ),
        ),
      )
    ];
  }
}
