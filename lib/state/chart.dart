import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/series.dart';
import 'package:rubintv_visualization/workspace/toolbar.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class ScatterChartState extends ChartLoadedState {
  final MultiSelectionTool tool;

  ScatterChartState({
    super.key,
    required super.id,
    required super.offset,
    super.title,
    required super.size,
    required super.series,
    required super.axisInfo,
    required super.legend,
    required super.useGlobalQuery,
    required super.chartType,
    required super.childKeys,
    required this.tool,
  });

  @override
  ScatterChartState copyWith({
    UniqueId? id,
    Offset? offset,
    Size? size,
    String? title,
    Map<SeriesId, SeriesInfo>? series,
    List<ChartAxisInfo>? axisInfo,
    Legend? legend,
    bool? useGlobalQuery,
    InteractiveChartTypes? chartType,
    MultiSelectionTool? tool,
  }) =>
      ScatterChartState(
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
        childKeys: childKeys,
        tool: tool ?? this.tool,
      );

  @override
  ChartInfo _internalBuildChartInfo({required List<Series> allSeries}) {
    if (chartType == InteractiveChartTypes.cartesianScatter) {
      return CartesianScatterPlotInfo(
        id: id,
        allSeries: allSeries,
        legend: legend,
        axisInfo: _axisInfo,
        key: childKeys.first,
        cursorAction: tool.cursorAction,
      );
    } else if (chartType == InteractiveChartTypes.polarScatter) {
      return PolarScatterPlotInfo(
        id: id,
        allSeries: allSeries,
        legend: legend,
        axisInfo: _axisInfo,
        key: childKeys.first,
        cursorAction: tool.cursorAction,
      );
    }
    throw UnimplementedError("Unknown chart type: $chartType");
  }

  @override
  Widget? createToolbar(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);

    List<Widget> tools = [
      SegmentedButton<MultiSelectionTool>(
        selected: {tool},
        segments: [
          ButtonSegment(
            value: MultiSelectionTool.select,
            icon: Icon(MultiSelectionTool.select.icon, color: workspace.theme.themeData.primaryColor),
          ),
          ButtonSegment(
            value: MultiSelectionTool.drillDown,
            icon: Icon(MultiSelectionTool.drillDown.icon, color: workspace.theme.themeData.primaryColor),
          ),
          ButtonSegment(
            value: MultiSelectionTool.dateTimeSelect,
            icon: Icon(MultiSelectionTool.dateTimeSelect.icon, color: workspace.theme.themeData.primaryColor),
          ),
        ],
        onSelectionChanged: (Set<MultiSelectionTool> selection) {
          MultiSelectionTool tool = selection.first;
          print("selected tool: $tool");
          workspace.dispatch(UpdateMultiSelect(selection.first, id));
        },
      ),
      ...getDefaultTools(context)
    ];

    return Row(children: tools);
  }

  @override
  bool get useSelectionController => tool == MultiSelectionTool.select;

  @override
  bool get useDrillDownController => tool == MultiSelectionTool.drillDown;
}

class BinnedChartState extends ChartLoadedState {
  final int nBins;
  final MultiSelectionTool tool;
  final TextEditingController _binController = TextEditingController();

  BinnedChartState({
    super.key,
    required super.id,
    required super.offset,
    super.title,
    required super.size,
    required super.series,
    required super.axisInfo,
    required super.legend,
    required super.useGlobalQuery,
    required super.chartType,
    required super.childKeys,
    required this.nBins,
    required this.tool,
  }) {
    _binController.text = nBins.toString();
  }

  @override
  BinnedChartState copyWith({
    UniqueId? id,
    Offset? offset,
    Size? size,
    String? title,
    Map<SeriesId, SeriesInfo>? series,
    List<ChartAxisInfo>? axisInfo,
    Legend? legend,
    bool? useGlobalQuery,
    InteractiveChartTypes? chartType,
    int? nBins,
    MultiSelectionTool? tool,
  }) =>
      BinnedChartState(
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
        childKeys: childKeys,
        nBins: nBins ?? this.nBins,
        tool: tool ?? this.tool,
      );

  @override
  ChartInfo _internalBuildChartInfo({required List<Series> allSeries}) {
    if (chartType == InteractiveChartTypes.histogram) {
      return HistogramInfo(
        id: id,
        allSeries: allSeries,
        legend: legend,
        axisInfo: _axisInfo,
        key: childKeys.first,
        nBins: nBins,
      );
    } else if (chartType == InteractiveChartTypes.box) {
      return BoxChartInfo(
        id: id,
        allSeries: allSeries,
        legend: legend,
        axisInfo: _axisInfo,
        key: childKeys.first,
        nBins: nBins,
      );
    }
    throw UnimplementedError("Unknown chart type: $chartType");
  }

  @override
  Widget? createToolbar(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);

    List<Widget> tools = [
      SizedBox(
          width: 100,
          child: TextField(
            controller: _binController,
            decoration: const InputDecoration(
              labelText: "bins",
            ),
            onSubmitted: (String value) {
              int? nBins = int.tryParse(value);
              if (nBins != null && nBins > 0) {
                workspace.dispatch(UpdateChartBinsAction(
                  chartId: id,
                  nBins: nBins,
                ));
              }
            },
          )),
      SegmentedButton<MultiSelectionTool>(
        selected: {tool},
        segments: [
          ButtonSegment(
            value: MultiSelectionTool.select,
            icon: Icon(Icons.touch_app, color: workspace.theme.themeData.primaryColor),
          ),
          ButtonSegment(
            value: MultiSelectionTool.drillDown,
            icon: Icon(Icons.query_stats, color: workspace.theme.themeData.primaryColor),
          ),
        ],
        onSelectionChanged: (Set<MultiSelectionTool> selection) {
          MultiSelectionTool tool = selection.first;
          print("selected tool: $tool");
          workspace.dispatch(UpdateMultiSelect(selection.first, id));
        },
      ),
      ...getDefaultTools(context)
    ];

    return Row(children: tools);
  }

  @override
  bool get useSelectionController => tool == MultiSelectionTool.select;

  @override
  bool get useDrillDownController => tool == MultiSelectionTool.drillDown;
}

class ChartWindowViewer extends StatefulWidget {
  final ChartLoadedState chartWindow;

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
      info: widget.chartWindow.buildChartInfo(workspace),
      selectionController: workspace.selectionController,
      drillDownController: workspace.drillDownController,
    );
  }

  @override
  Widget build(BuildContext context) {
    return chart;
  }
}
