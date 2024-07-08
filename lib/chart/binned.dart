import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';
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
    required super.resetController,
    super.needsReset,
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
    StreamController<ResetChartAction>? resetController,
    bool? needsReset,
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
        resetController: resetController ?? this.resetController,
        needsReset: needsReset ?? false,
      );
}

class BinnedChartWidget extends StatelessWidget {
  final Window window;

  BinnedChartWidget({
    super.key,
    required this.window,
  });

  final TextEditingController _binController = TextEditingController();
  final StreamController<ResetChartAction> resetController = StreamController<ResetChartAction>.broadcast();

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
          if (state.needsReset) {
            context.read<ChartBloc>().add(ResetChartEvent(ChartResetTypes.full));
          }

          WorkspaceViewerState workspace = WorkspaceViewer.of(context);
          SelectionController? selectionController;
          SelectionController? drillDownController;
          if (state.useDrillDownController) {
            drillDownController = ControlCenter().drillDownController;
          }
          if (state.useSelectionController) {
            selectionController = ControlCenter().selectionController;
          }
          _binController.text = state.nBins.toString();

          return ResizableWindow(
            info: window,
            toolbar: Row(children: [
              SizedBox(
                  width: 50,
                  child: TextField(
                    controller: _binController,
                    decoration: const InputDecoration(
                      labelText: "bins",
                    ),
                    onSubmitted: (String value) {
                      int? nBins = int.tryParse(value);
                      if (nBins != null && nBins > 0) {
                        context.read<ChartBloc>().add(UpdateBinsEvent(nBins));
                      }
                    },
                  )),
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
              resetController: resetController,
              legendSelectionCallback: context.read<ChartBloc>().onLegendSelect,
              onTapAxis: context.read<ChartBloc>().onAxisTap,
            ),
          );
        },
      ),
    );
  }
}
