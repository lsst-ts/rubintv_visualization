import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/binned.dart';
import 'package:rubintv_visualization/chart/scatter.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/websocket.dart';
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

/// Update a [Series] in a chart.
class UpdateSeriesEvent extends ChartEvent {
  final SeriesInfo series;
  final String? obsDate;
  final Query? globalQuery;
  final SchemaField? groupByColumn;

  UpdateSeriesEvent({
    required this.series,
    required this.obsDate,
    required this.globalQuery,
    this.groupByColumn,
  });
}

class UpdateBinsEvent extends ChartEvent {
  final int nBins;

  UpdateBinsEvent(this.nBins);
}

abstract class ChartState {
  UniqueId id;

  ChartState(this.id);
}

class ChartStateInitial extends ChartState {
  ChartStateInitial(super.id);
}

/// Persistable information to generate a chart
class ChartStateLoaded extends ChartState {
  final Map<SeriesId, SeriesInfo> _series;
  final Legend? legend;
  final List<ChartAxisInfo> _axisInfo;

  /// Whether or not to use the global query for all series in this [ChartLoadedState].
  final bool useGlobalQuery;

  //final DataCenter dataCenter;

  final WindowTypes chartType;

  final MultiSelectionTool tool;

  ChartStateLoaded({
    required UniqueId id,
    required Map<SeriesId, SeriesInfo> series,
    required List<ChartAxisInfo> axisInfo,
    required this.legend,
    required this.useGlobalQuery,
    required this.chartType,
    required this.tool,
  })  : _series = Map<SeriesId, SeriesInfo>.unmodifiable(series),
        _axisInfo = List<ChartAxisInfo>.unmodifiable(axisInfo),
        super(id);

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
    WindowTypes? chartType,
    MultiSelectionTool? tool,
  }) =>
      ChartStateLoaded(
        id: id ?? this.id,
        series: series ?? _series,
        axisInfo: axisInfo ?? _axisInfo,
        legend: legend ?? this.legend,
        useGlobalQuery: useGlobalQuery ?? this.useGlobalQuery,
        chartType: chartType ?? this.chartType,
        tool: tool ?? this.tool,
      );

  /// Whether or not at least one [PlotAxis] has been set.
  bool get hasAxes => axisInfo.isNotEmpty;

  /// Whether or not at least one [Series] has been initialized.
  bool get hasSeries => _series.isNotEmpty;

  List<Series> get allSeries {
    List<Series> allSeries = [];
    for (SeriesInfo seriesInfo in _series.values) {
      Series? series = seriesInfo.toSeries();
      if (series != null) {
        allSeries.add(series);
      }
    }
    return allSeries;
  }
}

class ChartBloc extends Bloc<ChartEvent, ChartState> {
  late StreamSubscription _subscription;

  ChartBloc(UniqueId id) : super(ChartStateInitial(id)) {
    /// Listen for messages from the websocket.
    _subscription = WebSocketManager().messages.listen((message) {
      add(ChartReceiveMessageEvent(message));
    });

    /// A message is received from the websocket.
    on<ChartReceiveMessageEvent>((event, emit) {
      if (this.state is ChartStateInitial) {
        return;
      }
      ChartStateLoaded state = this.state as ChartStateLoaded;
      DataCenter dataCenter = DataCenter();
      developer.log("received message: ${event.message.keys}, requestId: ${event.message['requestId']}",
          name: "rubin_chart.workspace");
      List<String>? splitId = event.message["requestId"]?.split(",");
      if (splitId == null || splitId.length != 2) {
        return;
      }
      UniqueId windowId = UniqueId.fromString(splitId[0]);
      SeriesId seriesId = SeriesId.fromString(splitId[1]);

      if (event.message["type"] == "table columns" && windowId == state.id) {
        developer.log(
            "received ${event.message["content"]["data"].length} columns for ${event.message["requestId"]}",
            name: "rubin_chart.workspace");
        dataCenter.updateSeriesData(
          series: state.series[seriesId]!,
          dataSourceName: event.message["content"]["schema"],
          plotColumns: List<String>.from(event.message["content"]["columns"].map((e) => e)),
          data: Map<String, List<dynamic>>.from(
              event.message["content"]["data"].map((key, value) => MapEntry(key, List<dynamic>.from(value)))),
        );
        developer.log("dataCenter data: ${dataCenter.seriesIds}", name: "rubin_chart.workspace");
      }
      emit(state.copyWith());
    });

    on<InitializeScatterPlotEvent>((event, emit) {
      emit(ChartStateLoaded(
        id: event.id,
        series: {},
        axisInfo: event.axisInfo,
        legend: Legend(),
        useGlobalQuery: true,
        chartType: event.chartType,
        tool: MultiSelectionTool.select,
      ));
    });

    on<InitializeBinnedEvent>((event, emit) {
      emit(BinnedState(
        id: event.id,
        series: {},
        axisInfo: event.axisInfo,
        legend: Legend(),
        useGlobalQuery: true,
        chartType: event.chartType,
        tool: MultiSelectionTool.select,
        nBins: 20,
      ));
    });

    /// Change the selection tool.
    on<UpdateMultiSelect>((event, emit) {
      ChartStateLoaded state = this.state as ChartStateLoaded;
      emit(state.copyWith(tool: event.tool));
    });

    /// Toggle the use of the global query in this Chart.
    on<UpdateChartGlobalQueryEvent>((event, emit) {
      ChartStateLoaded state = this.state as ChartStateLoaded;
      emit(state.copyWith(useGlobalQuery: event.useGlobalQuery));
    });

    /// Add a new series to the chart.
    on<CreateSeriesAction>((event, emit) {
      ChartStateLoaded state = this.state as ChartStateLoaded;

      Map<SeriesId, SeriesInfo> newSeries = {...state._series};
      newSeries[event.series.id] = event.series;
      emit(state.copyWith(series: newSeries));
    });

    on<UpdateSeriesEvent>((event, emit) {
      ChartStateLoaded state = this.state as ChartStateLoaded;

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
          if (axisInfo.label.startsWith("<") && axisInfo.label.endsWith(">")) {
            axesInfo[i] = axisInfo.copyWith(label: event.series.fields.values.toList()[i].name);
          }
        }
        emit(state.copyWith(series: newSeries, axisInfo: axesInfo));
      }
      updateSeriesData(
        series: event.series,
        globalQuery: event.globalQuery,
        obsDate: event.obsDate,
      );
    });

    /// Update the number of bins for a binned chart.
    on<UpdateBinsEvent>((event, emit) {
      BinnedState state = this.state as BinnedState;
      emit(state.copyWith(nBins: event.nBins));
    });
  }

  void updateSeriesData({
    required SeriesInfo series,
    required String? obsDate,
    required Query? globalQuery,
  }) {
    WebSocketManager websocket = WebSocketManager();
    if (websocket.isConnected) {
      ChartStateLoaded state = this.state as ChartStateLoaded;
      websocket.sendMessage(LoadColumnsCommand.build(
        seriesId: series.id,
        fields: series.fields.values.toList(),
        query: series.query,
        globalQuery: globalQuery,
        useGlobalQuery: state.useGlobalQuery,
        obsDate: obsDate,
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
  SeriesInfo nextSeries() {
    ChartStateLoaded state = this.state as ChartStateLoaded;

    SeriesId sid = SeriesId(windowId: state.id, id: nextSeriesId);
    DatabaseSchema database = DataCenter().databases.values.first;
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
    developer.log(
        "DataCenter keys: ${DataCenter().databases.keys}, instrument: ${workspace.info?.instrument?.name}");
    return showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: SeriesEditor(
          theme: workspace.theme,
          series: series,
          isNew: isNew,
          workspace: workspace,
          chartBloc: this,
          databaseSchema: DataCenter().databases[workspace.info!.instrument!.schema]!,
        ),
      ),
    );
  }

  List<Widget> getDefaultTools(BuildContext context, StreamController<ResetChartAction> resetController) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    bool useGlobalQuery = false;
    if (state is ChartStateLoaded) {
      useGlobalQuery = (state as ChartStateLoaded).useGlobalQuery;
    }
    return [
      Tooltip(
        message: "Add a new series to the chart",
        child: IconButton(
          icon: const Icon(Icons.format_list_bulleted_add, color: Colors.green),
          onPressed: () {
            SeriesInfo newSeries = nextSeries();
            context.read<ChartBloc>().add(CreateSeriesAction(series: newSeries));
            _editSeries(context, newSeries, true);
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
                ));
          },
        ),
      ),
      const SizedBox(width: 10),
      Tooltip(
        message: "Reset the chart",
        child: IconButton(
          icon: const Icon(Icons.refresh, color: Colors.green),
          onPressed: () {
            resetController.add(ResetChartAction());
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
              context.read<WorkspaceBloc>().add(RemoveWindowEvent(state.id));
            },
          ),
        ),
      )
    ];
  }
}
