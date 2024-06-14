import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/series.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class UpdateBinsEvent extends ChartEvent {
  final int nBins;

  UpdateBinsEvent(this.nBins);
}

class BinnedState extends ChartStateLoaded {
  int nBins;

  BinnedState({
    required super.key,
    required super.id,
    required super.series,
    required super.axisInfo,
    required super.legend,
    required super.useGlobalQuery,
    required super.dataCenter,
    required super.childKeys,
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
    List<GlobalKey>? childKeys,
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
        dataCenter: dataCenter ?? this.dataCenter,
        childKeys: childKeys ?? this.childKeys,
        chartType: chartType ?? this.chartType,
        key: key,
        tool: tool ?? this.tool,
        nBins: nBins ?? this.nBins,
      );
}

class BinnedBloc extends ChartBloc {
  late StreamSubscription _subscription;

  BinnedBloc() {
    /// Listen for messages from the websocket.
    _subscription = WebSocketManager().messages.listen((message) {
      add(ChartReceiveMessageEvent(message));
    });

    /// A message is received from the websocket.
    on<ChartReceiveMessageEvent>((event, emit) {
      onReceiveMesssage(event, emit);
    });

    on<UpdateBinsEvent>((event, emit) {
      BinnedState state = this.state as BinnedState;
      emit(state.copyWith(nBins: event.nBins));
    });
  }
}

class HistogramChart extends StatelessWidget {
  final Window window;

  const HistogramChart({
    super.key,
    required this.window,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BinnedBloc(),
      child: BlocBuilder<BinnedBloc, ChartState>(
        builder: (context, state) {
          WorkspaceViewerState workspace = WorkspaceViewer.of(context);
          SelectionController? selectionController;
          SelectionController? drillDownController;
          if (state is BinnedState) {
            if (state.useDrillDownController) {
              drillDownController = workspace.drillDownController;
            }
            if (state.useSelectionController) {
              selectionController = workspace.selectionController;
            }
          }

          if (state is! BinnedState) {
            return ResizableWindow(
                info: window,
                title: "loading...",
                toolbar: Row(children: [Spacer(), ...context.read<BinnedBloc>().getDefaultTools(context)]),
                child: const Center(
                  child: CircularProgressIndicator(),
                ));
          }

          return ResizableWindow(
              info: window,
              toolbar: Row(children: [
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
                    print("selected tool: $tool");
                    context.read<BinnedBloc>().add(UpdateMultiSelect(selection.first));
                  },
                ),
                ...context.read<BinnedBloc>().getDefaultTools(context)
              ]),
              title: null,
              child: RubinChart(
                key: state.key,
                info: HistogramInfo(
                  id: window.id,
                  allSeries: state.getAllSeries(),
                  legend: state.legend,
                  axisInfo: state.axisInfo,
                  key: state.childKeys.first,
                  nBins: state.nBins,
                ),
                selectionController: selectionController,
                drillDownController: drillDownController,
              ));
        },
      ),
    );
  }
}
