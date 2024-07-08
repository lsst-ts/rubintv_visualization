import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class InitializeScatterPlotEvent extends ChartEvent {
  final UniqueId id;
  final List<ChartAxisInfo> axisInfo;
  final WindowTypes chartType;

  InitializeScatterPlotEvent({
    required this.id,
    required this.axisInfo,
    required this.chartType,
  });
}

class ScatterPlotWidget extends StatelessWidget {
  final Window window;

  const ScatterPlotWidget({
    super.key,
    required this.window,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        List<ChartAxisInfo> axisInfo = [];
        if (window.type == WindowTypes.cartesianScatter) {
          axisInfo = [
            ChartAxisInfo(
              label: "<x>",
              axisId: AxisId(AxisLocation.bottom),
            ),
            ChartAxisInfo(
              label: "<y>",
              axisId: AxisId(AxisLocation.left),
              isInverted: true,
            ),
          ];
        } else if (window.type == WindowTypes.polarScatter) {
          axisInfo = [
            ChartAxisInfo(
              label: "<r>",
              axisId: AxisId(AxisLocation.radial),
            ),
            ChartAxisInfo(
              label: "<θ>",
              axisId: AxisId(AxisLocation.angular),
              isInverted: true,
            ),
          ];
        } else {
          throw Exception("Invalid window type: ${window.type}");
        }
        return ChartBloc(window.id)
          ..add(InitializeScatterPlotEvent(
            id: window.id,
            axisInfo: axisInfo,
            chartType: window.type,
          ));
      },
      child: BlocBuilder<ChartBloc, ChartState>(
        builder: (context, state) {
          if (state is! ChartStateLoaded) {
            /// Display an empty window while the chart is loading
            return ResizableWindow(
              info: window,
              title: "loading...",
              toolbar: Row(children: [...context.read<ChartBloc>().getDefaultTools(context)]),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          if (state.needsReset) {
            context.read<ChartBloc>().add(ResetChartEvent(ChartResetTypes.full));
          }

          WorkspaceViewerState workspace = WorkspaceViewer.of(context);
          SelectionController selectionController = ControlCenter().selectionController;
          SelectionController drillDownController = ControlCenter().drillDownController;

          return ResizableWindow(
            info: window,
            toolbar: Row(
              children: [
                SegmentedButton<MultiSelectionTool>(
                  selected: {state.tool},
                  segments: [
                    ButtonSegment(
                      value: MultiSelectionTool.select,
                      icon:
                          Icon(MultiSelectionTool.select.icon, color: workspace.theme.themeData.primaryColor),
                    ),
                    ButtonSegment(
                      value: MultiSelectionTool.drillDown,
                      icon: Icon(MultiSelectionTool.drillDown.icon,
                          color: workspace.theme.themeData.primaryColor),
                    ),
                    /*ButtonSegment(
                      value: MultiSelectionTool.dateTimeSelect,
                      icon: Icon(MultiSelectionTool.dateTimeSelect.icon,
                          color: workspace.theme.themeData.primaryColor),
                    ),*/
                  ],
                  onSelectionChanged: (Set<MultiSelectionTool> selection) {
                    MultiSelectionTool tool = selection.first;
                    developer.log("selected tool: $tool", name: "rubinTV.visualization.chart.scatter");
                    context.read<ChartBloc>().add(UpdateMultiSelect(selection.first));
                  },
                ),
                ...context.read<ChartBloc>().getDefaultTools(context),
              ],
            ),
            title: null,
            child: RubinChart(
              info: window.type == WindowTypes.cartesianScatter
                  ? CartesianScatterPlotInfo(
                      id: window.id,
                      allSeries: state.allSeries,
                      legend: state.legend,
                      axisInfo: state.axisInfo,
                      cursorAction: state.tool.cursorAction,
                    )
                  : PolarScatterPlotInfo(
                      id: window.id,
                      allSeries: state.allSeries,
                      legend: state.legend,
                      axisInfo: state.axisInfo,
                      cursorAction: state.tool.cursorAction,
                    ),
              selectionController: selectionController,
              drillDownController: drillDownController,
              resetController: state.resetController,
              legendSelectionCallback: context.read<ChartBloc>().onLegendSelect,
              onTapAxis: context.read<ChartBloc>().onAxisTap,
            ),
          );
        },
      ),
    );
  }
}
