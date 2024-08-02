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

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// An event used to initialize a scatter plot chart.
class InitializeScatterPlotEvent extends ChartEvent {
  /// The unique identifier for the chart.
  final UniqueId id;

  /// The axis information for the chart.
  final List<ChartAxisInfo> axisInfo;

  /// The type of chart to display.
  final WindowTypes chartType;

  InitializeScatterPlotEvent({
    required this.id,
    required this.axisInfo,
    required this.chartType,
  });
}

/// The [Widget] used to display a scatter plot.
class ScatterPlotWidget extends StatelessWidget {
  /// The [WindowMetaData] that contains the scatter plot and displays it on the screen.
  final WindowMetaData window;
  final ChartBloc bloc;

  const ScatterPlotWidget({
    super.key,
    required this.window,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChartBloc>.value(
      value: bloc,
      child: BlocBuilder<ChartBloc, ChartState>(
        builder: (context, state) {
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
              info: window.windowType == WindowTypes.cartesianScatter
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
