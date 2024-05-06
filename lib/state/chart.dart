import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/series.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// The type of chart to display.
enum InteractiveChartTypes {
  histogram,
  box,
  cartesianScatter,
  polarScatter,
  combination,
}

class CreateSeriesAction extends UiAction {
  final SeriesInfo series;

  CreateSeriesAction({
    required this.series,
  });
}

/// Persistable information to generate a chart
class ChartWindow extends Window {
  final Map<SeriesId, SeriesInfo> _series;
  final Legend? legend;
  final List<ChartAxisInfo> _axisInfo;

  final InteractiveChartTypes chartType;

  /// Whether or not to use the global query for all series in this [ChartWindow].
  final bool useGlobalQuery;

  ChartWindow({
    super.key,
    required super.id,
    required super.offset,
    super.title,
    required super.size,
    required Map<SeriesId, SeriesInfo> series,
    required List<ChartAxisInfo> axisInfo,
    required this.legend,
    required this.useGlobalQuery,
    required this.chartType,
  })  : _series = Map<SeriesId, SeriesInfo>.unmodifiable(series),
        _axisInfo = List<ChartAxisInfo>.unmodifiable(axisInfo);

  /// Return a copy of the internal [Map] of [SeriesInfo], to prevent updates.
  Map<SeriesId, SeriesInfo> get series => {..._series};

  /// Return a copy of the internal [List] of [ChartAxisInfo], to prevent updates.
  List<ChartAxisInfo?> get axes => [..._axisInfo];

  static ChartWindow fromChartType({
    required UniqueId id,
    required Offset offset,
    required Size size,
    required InteractiveChartTypes chartType,
  }) {
    List<ChartAxisInfo> axisInfo = [];
    switch (chartType) {
      case InteractiveChartTypes.histogram:
        axisInfo = [
          ChartAxisInfo(
            label: "x",
            axisId: AxisId(AxisLocation.bottom),
          ),
        ];
        break;
      case InteractiveChartTypes.cartesianScatter || InteractiveChartTypes.box:
        axisInfo = [
          ChartAxisInfo(
            label: "x",
            axisId: AxisId(AxisLocation.bottom),
          ),
          ChartAxisInfo(
            label: "y",
            axisId: AxisId(AxisLocation.left),
            isInverted: true,
          ),
        ];
        break;
      case InteractiveChartTypes.polarScatter:
        axisInfo = [
          ChartAxisInfo(
            label: "r",
            axisId: AxisId(AxisLocation.radial),
          ),
          ChartAxisInfo(
            label: "θ",
            axisId: AxisId(AxisLocation.angular),
          ),
        ];
        break;
      case InteractiveChartTypes.combination:
        throw UnimplementedError("Combination charts have not yet been implemented.");
    }

    return ChartWindow(
      id: id,
      offset: offset,
      size: size,
      series: {},
      axisInfo: axisInfo,
      legend: Legend(),
      useGlobalQuery: true,
      chartType: chartType,
    );
  }

  @override
  ChartWindow copyWith({
    UniqueId? id,
    Offset? offset,
    Size? size,
    String? title,
    Map<SeriesId, SeriesInfo>? series,
    List<ChartAxisInfo>? axisInfo,
    Legend? legend,
    bool? useGlobalQuery,
    InteractiveChartTypes? chartType,
  }) =>
      ChartWindow(
        id: id ?? this.id,
        offset: offset ?? this.offset,
        size: size ?? this.size,
        title: title ?? this.title,
        series: series ?? _series,
        axisInfo: axisInfo ?? _axisInfo,
        legend: legend ?? this.legend,
        useGlobalQuery: useGlobalQuery ?? this.useGlobalQuery,
        chartType: chartType ?? this.chartType,
        key: key,
      );

  ChartInfo buildChartInfo(DataCenter dataCenter) {
    List<Series> allSeries = [];
    for (SeriesInfo seriesInfo in _series.values) {
      Series? series = seriesInfo.toSeries(dataCenter);
      if (series != null) {
        allSeries.add(series);
      }
    }
    switch (chartType) {
      case InteractiveChartTypes.histogram:
        return HistogramInfo(
          id: id,
          allSeries: allSeries,
          legend: legend,
          axisInfo: _axisInfo,
          nBins: 20,
        );
      case InteractiveChartTypes.cartesianScatter:
        return CartesianScatterPlotInfo(
          id: id,
          allSeries: allSeries,
          legend: legend,
          axisInfo: _axisInfo,
        );
      case InteractiveChartTypes.polarScatter:
        return PolarScatterPlotInfo(
          id: id,
          allSeries: allSeries,
          legend: legend,
          axisInfo: _axisInfo,
        );
      default:
        throw UnimplementedError("Unknown chart type: $chartType");
    }
  }

  /// Create a new [Widget] to display in a [WorkspaceViewer].
  @override
  Widget createWidget(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return RubinChart(
      key: key,
      info: buildChartInfo(workspace.dataCenter),
      selectionController: workspace.selectionController,
      drillDownController: workspace.drillDownController,
    );
  }

  /// Whether or not at least one [PlotAxis] has been set.
  bool get hasAxes => axes.isNotEmpty;

  /// Whether or not at least one [Series] has been initialized.
  bool get hasSeries => _series.isNotEmpty;

  /// Check if a series is compatible with this chart.
  /// Any mismatched columns have their indices returned.
  List<AxisId>? canAddSeries({
    required SeriesInfo series,
    required DataCenter dataCenter,
  }) {
    final List<AxisId> mismatched = [];
    // Check that the series has the correct number of columns and axes
    if (series.fields.length != axes.length) {
      developer.log("bad axes", name: "rubin_chart.core.chart.dart");
      return null;
    }
    for (AxisId sid in series.fields.keys) {
      SchemaField field = series.fields[sid]!;
      for (SeriesInfo otherSeries in _series.values) {
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

  /// Update [ChartWindow] when [Series] is updated.
  ChartWindow addSeries({
    required SeriesInfo series,
  }) {
    Map<SeriesId, SeriesInfo> newSeries = {..._series};
    newSeries[series.id] = series;
    return copyWith(series: newSeries);
  }

  BigInt get nextSeriesId {
    BigInt maxId = BigInt.zero;
    for (SeriesId sid in _series.keys) {
      if (sid.id > maxId) {
        maxId = sid.id;
      }
    }
    return maxId + BigInt.one;
  }

  /// Create a new empty Series for this [ChartWindow].
  SeriesInfo nextSeries({required DataCenter dataCenter}) {
    SeriesId sid = SeriesId(windowId: id, id: nextSeriesId);
    DatabaseSchema database = dataCenter.databases.values.first;
    TableSchema table = database.tables.values.first;
    Map<AxisId, SchemaField> fields = {};
    for (int i = 0; i < axes.length; i++) {
      fields[axes[i]!.axisId] = table.fields.values.toList()[i];
    }
    return SeriesInfo(
      id: sid,
      name: "Series-${id.id}",
      axes: axes.map((ChartAxisInfo? info) => info!.axisId).toList(),
      fields: fields,
    );
  }

  int get nMaxAxes {
    if (chartType == InteractiveChartTypes.histogram) {
      return 1;
    } else if (chartType == InteractiveChartTypes.cartesianScatter) {
      return 2;
    } else if (chartType == InteractiveChartTypes.polarScatter) {
      return 2;
    } else if (chartType == InteractiveChartTypes.combination) {
      return 2;
    }
    throw UnimplementedError("Unknown chart type: $chartType");
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
          dispatch: workspace.dispatch,
        ),
      ),
    );
  }

  @override
  Widget? createToolbar(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return Row(children: [
      Tooltip(
        message: "Add a new series to the chart",
        child: IconButton(
          icon: const Icon(Icons.format_list_bulleted_add, color: Colors.green),
          onPressed: () {
            SeriesInfo newSeries = nextSeries(dataCenter: workspace.dataCenter);
            workspace.dispatch(CreateSeriesAction(series: newSeries));
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
            workspace.dispatch(UpdateChartGlobalQueryAction(
              useGlobalQuery: !useGlobalQuery,
              dataCenter: workspace.dataCenter,
              chartId: id,
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
              workspace.dispatch(RemoveWindowAction(this));
            },
          ),
        ),
      )
    ]);
  }
}

class ChartWindowViewer extends StatefulWidget {
  final ChartWindow chartWindow;

  const ChartWindowViewer({
    super.key,
    required this.chartWindow,
  });

  @override
  ChartWindowViewerState createState() => ChartWindowViewerState();
}

class ChartWindowViewerState extends State<ChartWindowViewer> {
  late RubinChart chart;

  @override
  void initState() {
    super.initState();
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    chart = RubinChart(
      info: widget.chartWindow.buildChartInfo(workspace.dataCenter),
      selectionController: workspace.selectionController,
      drillDownController: workspace.drillDownController,
    );
  }

  @override
  Widget build(BuildContext context) {
    return chart;
  }
}
