import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class CartesianScatterPlot extends StatelessWidget {
  final Window window;

  const CartesianScatterPlot({
    super.key,
    required this.window,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ChartBloc(),
      child: BlocBuilder<ChartBloc, ChartState>(
        builder: (context, state) {
          if (state is! ChartStateLoaded) {
            /// Display an empty window while the chart is loading
            return ResizableWindow(
                info: window,
                title: "loading...",
                toolbar:
                    Row(children: [const Spacer(), ...context.read<ChartBloc>().getDefaultTools(context)]),
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
                    ButtonSegment(
                      value: MultiSelectionTool.dateTimeSelect,
                      icon: Icon(MultiSelectionTool.dateTimeSelect.icon,
                          color: workspace.theme.themeData.primaryColor),
                    ),
                  ],
                  onSelectionChanged: (Set<MultiSelectionTool> selection) {
                    MultiSelectionTool tool = selection.first;
                    developer.log("selected tool: $tool", name: "rubinTV.visualization.chart.scatter");
                    context.read<ChartBloc>().add(UpdateMultiSelect(selection.first));
                  },
                ),
                ...context.read<ChartBloc>().getDefaultTools(context)
              ],
            ),
            title: null,
            child: RubinChart(
              key: state.key,
              info: CartesianScatterPlotInfo(
                id: window.id,
                allSeries: state.allSeries,
                legend: state.legend,
                axisInfo: state.axisInfo,
                key: state.childKeys.first,
                cursorAction: state.tool.cursorAction,
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
