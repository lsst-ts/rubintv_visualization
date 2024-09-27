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
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// An event used to initialize a binned chart.
class InitializeBinnedEvent extends ChartEvent {
  /// The unique identifier for the chart.
  final UniqueId id;

  /// The axis information for the chart.
  final List<ChartAxisInfo> axisInfo;

  /// The type of chart to display.
  final WindowTypes chartType;

  InitializeBinnedEvent({
    required this.id,
    required this.axisInfo,
    required this.chartType,
  });
}

/// The state of a binned chart.
class BinnedState extends ChartState {
  /// The number of bins to use in the chart.
  int nBins;

  BinnedState({
    required super.id,
    required super.series,
    required super.axisInfo,
    required super.legend,
    required super.useGlobalQuery,
    required super.windowType,
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
    WindowTypes? windowType,
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
        windowType: windowType ?? this.windowType,
        tool: tool ?? this.tool,
        nBins: nBins ?? this.nBins,
        resetController: resetController ?? this.resetController,
        needsReset: needsReset ?? false,
      );

  @override
  Map<String, dynamic> toJson() {
    return {
      "id": id.toSerializableString(),
      "series": series.values.map((e) => e.toJson()).toList(),
      "axisInfo": axisInfo.map((e) => e.toJson()).toList(),
      "legend": legend?.toJson(),
      "useGlobalQuery": useGlobalQuery,
      "windowType": windowType.name,
      "tool": tool.toString(),
      "nBins": nBins,
    };
  }

  @override
  factory BinnedState.fromJson(Map<String, dynamic> json) {
    return BinnedState(
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
      nBins: json["nBins"],
      resetController: StreamController<ResetChartAction>.broadcast(),
    );
  }
}

/// The [Widget] used to display a binned chart.
class BinnedChartWidget extends StatelessWidget {
  /// The [WindowMetaData that contains the chart and displays it on the screen.
  final WindowMetaData window;
  final ChartBloc bloc;

  BinnedChartWidget({
    super.key,
    required this.window,
    required this.bloc,
  });

  /// The [TextEditingController] used to control the number of bins in the chart.
  final TextEditingController _binController = TextEditingController();

  /// The [StreamController] used to reset the chart.
  final StreamController<ResetChartAction> resetController = StreamController<ResetChartAction>.broadcast();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ChartBloc>.value(
      value: bloc,
      child: BlocBuilder<ChartBloc, WindowState>(
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
              Tooltip(
                message: "Change number of bins",
                child: SizedBox(
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
                  ),
                ),
              ),
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
              info: window.windowType == WindowTypes.histogram
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
