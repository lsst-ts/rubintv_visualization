import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/series.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class InitializeBinnedEvent extends ChartEvent {
  final UniqueId id;
  final List<ChartAxisInfo> axisInfo;
  final WindowTypes chartType;

  InitializeBinnedEvent({
    required this.id,
    required this.axisInfo,
    required this.chartType,
  });
}

class BinnedState extends ChartStateLoaded {
  int nBins;

  BinnedState({
    required super.id,
    required super.series,
    required super.axisInfo,
    required super.legend,
    required super.useGlobalQuery,
    required super.chartType,
    required super.tool,
    required this.nBins,
  });

  @override
  BinnedState copyWith({
    UniqueId? id,
    Map<SeriesId, SeriesInfo>? series,
    List<ChartAxisInfo>? axisInfo,
    Legend? legend,
    bool? useGlobalQuery,
    DataCenter? dataCenter,
    WindowTypes? chartType,
    MultiSelectionTool? tool,
    int? nBins,
  }) =>
      BinnedState(
        id: id ?? this.id,
        series: series ?? this.series,
        axisInfo: axisInfo ?? this.axisInfo,
        legend: legend ?? this.legend,
        useGlobalQuery: useGlobalQuery ?? this.useGlobalQuery,
        chartType: chartType ?? this.chartType,
        tool: tool ?? this.tool,
        nBins: nBins ?? this.nBins,
      );
}

class BinnedChartWidget extends StatelessWidget {
  final Window window;

  const BinnedChartWidget({
    super.key,
    required this.window,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        List<ChartAxisInfo> axisInfo = [
          ChartAxisInfo(
            label: "<x>",
            axisId: AxisId(AxisLocation.bottom),
          ),
        ];
        if (window.type == WindowTypes.box) {
          axisInfo.add(ChartAxisInfo(
            label: "<y>",
            axisId: AxisId(AxisLocation.left),
          ));
        }
        return ChartBloc(window.id)
          ..add(InitializeBinnedEvent(
            id: window.id,
            axisInfo: axisInfo,
            chartType: window.type,
          ));
      },
      child: BlocBuilder<ChartBloc, ChartState>(
        builder: (context, state) {
          if (state is! BinnedState) {
            /// Display an empty window while the chart is loading
            return ResizableWindow(
                info: window,
                title: "loading...",
                toolbar: Row(children: [...context.read<ChartBloc>().getDefaultTools(context)]),
                child: const Center(
                  child: CircularProgressIndicator(),
                ));
          }

          WorkspaceViewerState workspace = WorkspaceViewer.of(context);
          SelectionController? selectionController;
          SelectionController? drillDownController;
          if (state.useDrillDownController) {
            drillDownController = workspace.drillDownController;
          }
          if (state.useSelectionController) {
            selectionController = workspace.selectionController;
          }

          return ResizableWindow(
            info: window,
            toolbar: Row(children: [
              SegmentedButton<MultiSelectionTool>(
                selected: {state.tool},
                segments: [
                  ButtonSegment(
                    value: MultiSelectionTool.select,
                    icon: Icon(MultiSelectionTool.select.icon, color: workspace.theme.themeData.primaryColor),
                  ),
                  ButtonSegment(
                    value: MultiSelectionTool.drillDown,
                    icon: Icon(MultiSelectionTool.drillDown.icon,
                        color: workspace.theme.themeData.primaryColor),
                  ),
                  ButtonSegment(
                    value: MultiSelectionTool.dateTimeSelect,
                    icon: Icon(MultiSelectionTool.dateTimeSelect.icon,
                        color: workspace.theme.themeData.primaryColor),
                  ),
                ],
                onSelectionChanged: (Set<MultiSelectionTool> selection) {
                  MultiSelectionTool tool = selection.first;
                  developer.log("selected tool: $tool", name: "rubinTV.visualization.chart.binned");
                  context.read<ChartBloc>().add(UpdateMultiSelect(selection.first));
                },
              ),
              ...context.read<ChartBloc>().getDefaultTools(context)
            ]),
            title: null,
            child: RubinChart(
              info: window.type == WindowTypes.histogram
                  ? HistogramInfo(
                      id: window.id,
                      allSeries: state.allSeries,
                      legend: state.legend,
                      axisInfo: state.axisInfo,
                      nBins: state.nBins,
                    )
                  : BoxChartInfo(
                      id: window.id,
                      allSeries: state.allSeries,
                      legend: state.legend,
                      axisInfo: state.axisInfo,
                      nBins: state.nBins,
                    ),
              selectionController: selectionController,
              drillDownController: drillDownController,
            ),
          );
        },
      ),
    );
  }
}
