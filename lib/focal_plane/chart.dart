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
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/focal_plane/editor.dart';
import 'package:rubintv_visualization/focal_plane/slider.dart';
import 'package:rubintv_visualization/focal_plane/viewer.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/primitives.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// Playback speed in milliseconds.
const int kDefaultPlaybackSpeed = 500;

/// factor to multiply the playback speed by.
const double kPlaybackSpeedStep = 1.25;

/// Format the obsDate (an integer of the form YYYYMMDD) as a string.
String formatObsDate(int dateNumber) {
  String dateString = dateNumber.toString().padLeft(8, '0');
  return '${dateString.substring(0, 4)}-${dateString.substring(4, 6)}-${dateString.substring(6)}';
}

/// An event in a [FocalPlaneChartBloc].
abstract class FocalPlaneChartEvent extends WindowEvent {}

/// An event to initialize the focal plane chart.
class InitializeFocalPlaneChartEvent extends FocalPlaneChartEvent {
  /// The unique identifier of the chart.
  final UniqueId id;

  /// The series information.
  final SeriesInfo series;

  /// The axis of the column being displayed.
  /// (required for bounds and to map the value of the column to a double).
  final ChartAxis dataAxis;

  /// The colorbar controller.
  final ColorbarController colorbarController;

  /// The global dayObs.
  /// If this is null no global dayObs is used and the chart can only be updated
  /// when points are selected in other charts.
  final String? dayObs;

  InitializeFocalPlaneChartEvent({
    required this.id,
    required this.series,
    required this.dataAxis,
    required this.colorbarController,
    required this.dayObs,
  });
}

/// An event when a message has been received from the websocket.
class FocalPlaneReceiveMessageEvent extends FocalPlaneChartEvent {
  /// The message received.
  final Map<String, dynamic> message;

  FocalPlaneReceiveMessageEvent(this.message);
}

/// An event to update the column being displayed.
class FocalPlaneUpdateColumnEvent extends FocalPlaneChartEvent {
  /// The field to plot.
  final SchemaField field;

  /// The global dayObs.
  final String? dayObs;

  /// The selected data points.
  final Set<DataId> selected;

  FocalPlaneUpdateColumnEvent({
    required this.field,
    required this.dayObs,
    required this.selected,
  });
}

/// An event to update the data index.
class FocalPlaneUpdateDataIndexEvent extends FocalPlaneChartEvent {
  /// The new index.
  final int index;

  FocalPlaneUpdateDataIndexEvent(this.index);
}

/// An event to increase the data index.
class FocalPlaneIncreaseDataIndexEvent extends FocalPlaneChartEvent {}

/// An event to update the playback speed.
class FocalPlaneUpdatePlaybackSpeedEvent extends FocalPlaneChartEvent {
  final double speed;

  FocalPlaneUpdatePlaybackSpeedEvent(this.speed);
}

/// An event to start the timer.
class FocalPlaneStartTimerEvent extends FocalPlaneChartEvent {}

/// An event to stop the timer.
class FocalPlaneStopTimerEvent extends FocalPlaneChartEvent {}

/// An event when a new tick is received.
class FocalPlaneTickEvent extends FocalPlaneChartEvent {}

/// An event to toggle the loop playback.
class FocalPlaneToggleLoopEvent extends FocalPlaneChartEvent {}

/// The loaded state of a [FocalPlaneChartBloc].
class FocalPlaneChartState extends WindowState {
  /// The series information.
  SeriesInfo series;

  /// The axis of the selected column.
  ChartAxis dataAxis;

  /// The axis of the "detector" value.
  /// We use the color axis, but really it isn't a color at all, it's the index of the detector
  /// in the focal plane.
  ChartAxisInfo detectorAxisInfo = ChartAxisInfo(label: "Detector", axisId: AxisId(AxisLocation.color));

  /// The data for each detector
  Map<DataId, Map<int, dynamic>> data;

  /// The list of data ids that can be cycled through.
  List<DataId> dataIds;

  /// The index of the current data point.
  int dataIndex;

  /// The colorbar controller.
  ColorbarController colorbarController;

  /// The playback speed.
  double playbackSpeed;

  /// Whether the playback is currently playing.
  bool isPlaying;

  /// Whether the playback should loop.
  bool loopPlayback;

  /// The global dayObs.
  String? dayObs;

  FocalPlaneChartState({
    required super.id,
    required this.series,
    required this.dataAxis,
    required this.data,
    required this.dataIds,
    required this.dataIndex,
    required this.colorbarController,
    required this.playbackSpeed,
    required this.isPlaying,
    required this.loopPlayback,
    required this.dayObs,
  }) : super(windowType: WindowTypes.focalPlane);

  /// Copy the state with new values.
  FocalPlaneChartState copyWith({
    UniqueId? id,
    SeriesInfo? series,
    ChartAxis? dataAxis,
    Map<DataId, Map<int, dynamic>>? data,
    List<DataId>? dataIds,
    int? dataIndex,
    ColorbarController? colorbarController,
    double? playbackSpeed,
    bool? isPlaying,
    bool? loopPlayback,
    String? dayObs,
  }) =>
      FocalPlaneChartState(
        id: id ?? this.id,
        series: series ?? this.series,
        dataAxis: dataAxis ?? this.dataAxis,
        data: data ?? this.data,
        dataIds: dataIds ?? this.dataIds,
        dataIndex: dataIndex ?? this.dataIndex,
        colorbarController: colorbarController ?? this.colorbarController,
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        isPlaying: isPlaying ?? this.isPlaying,
        loopPlayback: loopPlayback ?? this.loopPlayback,
        dayObs: dayObs ?? this.dayObs,
      );

  @override
  Map<String, dynamic> toJson() {
    return {
      "id": id.toSerializableString(),
      "series": series.toJson(),
      "axisInfo": dataAxis.info.toJson(),
      "playbackSpeed": playbackSpeed,
      "loopPlayback": loopPlayback,
      "dayObs": dayObs,
      "windowType": windowType.name,
    };
  }

  static FocalPlaneChartState fromJson(Map<String, dynamic> json, ChartTheme theme) {
    ChartAxisInfo axisInfo = ChartAxisInfo.fromJson(json["axisInfo"]);
    return FocalPlaneChartState(
      id: UniqueId.fromString(json["id"]),
      series: SeriesInfo.fromJson(json["series"]),
      dataAxis: createEmptyDataAxis(axisInfo, theme),
      data: {},
      dataIds: [],
      dataIndex: 0,
      colorbarController: ColorbarController(
        min: 0,
        max: 100,
        stops: {
          0: Colors.blue,
          100: Colors.red,
        },
      ),
      playbackSpeed: json["playbackSpeed"],
      isPlaying: false,
      loopPlayback: json["loopPlayback"],
      dayObs: json["dayObs"],
    );
  }

  /// Get the data axis id.
  AxisId get dataAxisId => dataAxis.info.axisId;
}

/// A bloc to manage the state of a focal plane chart.
class FocalPlaneChartBloc extends WindowBloc<FocalPlaneChartState> {
  /// The subscription to the websocket.
  late StreamSubscription _websocketSubscription;

  /// The subscription to the global query stream.
  late StreamSubscription _globalQuerySubscription;

  /// The play timer.
  Timer? _playTimer;

  /// The selection timer.
  Timer? _selectionTimer;

  void _updateSeries([Set<Object> dataPoints = const {}]) {
    add(FocalPlaneUpdateColumnEvent(
      field: state.series.fields.values.first,
      dayObs: state.dayObs,
      selected: dataPoints.map((e) => e as DataId).toSet(),
    ));
  }

  FocalPlaneChartBloc(super.initialState) {
    _websocketSubscription = WebSocketManager().messages.listen((message) {
      add(FocalPlaneReceiveMessageEvent(message));
    });

    /// Subscribe to the selection controller to update the chart when points are selected.
    /// We use a timer so that we don't load data until the selection has stopped
    ControlCenter().selectionController.subscribe(state.id, (Object? origin, Set<Object> dataPoints) {
      if (origin == state.id) {
        return;
      }
      _selectionTimer?.cancel();
      _selectionTimer = Timer(const Duration(milliseconds: 500), () {
        _updateSeries(dataPoints);
      });
    });

    /// Subscribe to the global query stream to update the chart when the query changes.
    _globalQuerySubscription = ControlCenter().globalQueryStream.listen((GlobalQuery? query) {
      Set<DataId>? selected =
          ControlCenter().selectionController.selectedDataPoints.map((e) => e as DataId).toSet();
      if (selected.isEmpty) {
        selected = ControlCenter().drillDownController.selectedDataPoints.map((e) => e as DataId).toSet();
      }
      if (selected.isEmpty) {
        selected = null;
      }
      _fetchSeriesData(series: state.series, query: query?.query, dayObs: query?.dayObs, selected: selected);
    });

    /// Initialize the chart.
    on<InitializeFocalPlaneChartEvent>((event, emit) {
      ColorbarController colorbarController = event.colorbarController;
      emit(FocalPlaneChartState(
        id: event.id,
        series: event.series,
        dataAxis: event.dataAxis,
        data: {},
        dataIds: [],
        dataIndex: 0,
        colorbarController: colorbarController,
        playbackSpeed: 1,
        isPlaying: false,
        loopPlayback: true,
        dayObs: event.dayObs,
      ));
    });

    /// Process data received from the websocket.
    on<FocalPlaneReceiveMessageEvent>((event, emit) {
      List<String>? splitId = event.message["requestId"]?.split(",");
      if (splitId == null || splitId.length != 2) {
        return;
      }
      UniqueId windowId = UniqueId.fromString(splitId[0]);

      if (event.message["type"] == "table columns" && windowId == state.id) {
        FocalPlaneChartState? newState = _updateSeriesData(event);
        if (newState != null) {
          emit(newState);
        }
      }
    });

    /// Update the Series and fetch the data.
    on<FocalPlaneUpdateColumnEvent>((event, emit) {
      final String tableName = event.field.schema.name;
      SchemaField detectorField;
      if (kExposureTables.contains(tableName)) {
        detectorField = event.field.database.tables["ccdexposure"]!.fields["detector"]!;
      } else if (kVisit1Tables.contains(tableName)) {
        detectorField = event.field.database.tables["ccdvisit1"]!.fields["detector"]!;
      } else {
        throw Exception("Unknown table name: $tableName");
      }

      SeriesInfo newSeries = SeriesInfo(
        id: state.series.id,
        name: state.series.name,
        axes: state.series.axes,
        fields: {
          state.dataAxis.info.axisId: event.field,
          state.detectorAxisInfo.axisId: detectorField,
        },
      );

      developer.log("Selected data points: ${event.selected}", name: "rubin_chart.focal_plane.chart.dart");

      bool isNewPlot = state.data.isEmpty;

      if (event.selected.isNotEmpty) {
        _fetchSeriesData(series: newSeries, selected: event.selected, isNewPlot: isNewPlot);
      } else if (event.dayObs != null) {
        _fetchSeriesData(series: newSeries, dayObs: event.dayObs, isNewPlot: isNewPlot);
      }

      emit(state.copyWith(series: newSeries));
    });

    /// Update the data index.
    on<FocalPlaneUpdateDataIndexEvent>((event, emit) {
      emit(state.copyWith(dataIndex: event.index));
    });

    /// Increase the data index.
    on<FocalPlaneIncreaseDataIndexEvent>((event, emit) {
      if (state.dataIndex < state.dataIds.length - 1) {
        emit(state.copyWith(dataIndex: state.dataIndex + 1));
      }
    });

    /// Update the playback speed.
    on<FocalPlaneUpdatePlaybackSpeedEvent>((event, emit) {
      emit(state.copyWith(playbackSpeed: event.speed));
      if (state.isPlaying) {
        _createTimer();
      }
    });

    /// Start the playback timer, which increases the [dataIndex] periodically.
    on<FocalPlaneStartTimerEvent>((event, emit) {
      _createTimer();
      int dataIndex = state.dataIndex;
      if (dataIndex == state.dataIds.length - 1) {
        dataIndex = 0;
      }
      emit(state.copyWith(isPlaying: true, dataIndex: dataIndex));
    });

    /// Stop the playback timer.
    on<FocalPlaneStopTimerEvent>((event, emit) {
      _playTimer?.cancel();
      _playTimer = null;
      emit(state.copyWith(isPlaying: false));
    });

    /// Update the data index when a tick is received.
    on<FocalPlaneTickEvent>((event, emit) {
      if (state.dataIndex < state.dataIds.length - 1) {
        emit(state.copyWith(dataIndex: state.dataIndex + 1));
      } else if (state.loopPlayback) {
        emit(state.copyWith(dataIndex: 0));
      } else {
        _playTimer?.cancel();
        emit(state.copyWith(isPlaying: false));
      }
    });

    /// Toggle the loop playback.
    on<FocalPlaneToggleLoopEvent>((event, emit) {
      emit(state.copyWith(loopPlayback: !state.loopPlayback));
    });

    /// Reload all of the data from the server.
    on<SynchDataEvent>((event, emit) {
      _updateSeries();
    });
  }

  /// Create the playback timer.
  void _createTimer() {
    _playTimer?.cancel();
    _playTimer = Timer.periodic(Duration(milliseconds: (kDefaultPlaybackSpeed / state.playbackSpeed).round()),
        (timer) {
      add(FocalPlaneTickEvent());
    });
  }

  /// Update the series data.
  FocalPlaneChartState? _updateSeriesData(FocalPlaneReceiveMessageEvent event) {
    // Extract result
    int rows = event.message["content"]["data"].values.first.length;
    int columns = event.message["content"]["data"].length;
    developer.log("received $columns columns and $rows rows for ${event.message["requestId"]}",
        name: "rubin_chart.workspace");

    if (rows > 0) {
      // Extract the data from the message
      Map<String, List<dynamic>> allData = Map<String, List<dynamic>>.from(
          event.message["content"]["data"].map((key, value) => MapEntry(key, List<dynamic>.from(value))));

      // Extract the dataID and the data
      Map<DataId, Map<int, dynamic>> data = {};
      List<dynamic> dynamicData = [];
      for (int i = 0; i < rows; i++) {
        DataId dataId = DataId(
          dayObs: allData["day_obs"]![i] as int,
          seqNum: allData["seq_num"]![i] as int,
        );
        if (!data.keys.contains(dataId)) {
          data[dataId] = {};
        }
        String detectorKey = allData.keys.where((key) => key.contains("detector")).first;
        String fieldName =
            allData.keys.where((key) => key != 'day_obs' && key != 'seq_num' && key != detectorKey).first;
        dynamic value = allData[fieldName]![i];
        data[dataId]![allData[detectorKey]![i] as int] = value;
        dynamicData.add(value);
      }

      // Sort by the DataIds to so that they are iterated in increasing dayObs, then seq_num.
      List<DataId> sortedIds = data.keys.toList();
      sortedIds.sort((a, b) {
        int dayObsComparison = a.dayObs.compareTo(b.dayObs);
        if (dayObsComparison != 0) {
          return dayObsComparison;
        }
        return a.seqNum.compareTo(b.seqNum);
      });

      // We also need to update the ChartAxis, since it is used to apply the colormap.
      ChartAxis dataAxis;
      SchemaField field = state.series.fields.values.first;
      if (field.isNumerical) {
        dataAxis = NumericalChartAxis.fromBounds(
          axisInfo: state.dataAxis.info,
          boundsList: [Bounds.fromList(dynamicData.map((e) => e.toDouble() as double).toList())],
          theme: state.dataAxis.theme,
        );
      } else if (field.isDateTime) {
        dataAxis = DateTimeChartAxis.fromData(
          axisInfo: state.dataAxis.info,
          data: [dynamicData.map((e) => e as DateTime).toList()],
          theme: state.dataAxis.theme,
        );
      } else {
        throw UnimplementedError("Unsupported field type: ${field.type}");
      }

      // Finally we need to update the ColorbarController so that the colors are displayed properly.
      ColorbarController colorbarController = state.colorbarController;
      colorbarController.updateBounds(min: dataAxis.bounds.min, max: dataAxis.bounds.max);

      return state.copyWith(data: data, dataAxis: dataAxis, dataIds: sortedIds, dataIndex: 0);
    }
    return null;
  }

  /// Request the data for the series from the server.
  void _fetchSeriesData({
    required SeriesInfo series,
    Set<DataId>? selected,
    QueryExpression? query,
    String? dayObs,
    bool isNewPlot = false,
  }) {
    WebSocketManager websocket = WebSocketManager();
    if (websocket.isConnected) {
      websocket.sendMessage(LoadColumnsCommand.build(
        seriesId: series.id,
        fields: series.fields.values.toList(),
        query: query,
        useGlobalQuery: false,
        dayObs: dayObs,
        windowId: state.id,
        dataIds: selected,
        isNewPlot: isNewPlot,
      ).toJson());
    }
  }

  /// Close the bloc.
  @override
  Future<void> close() {
    _websocketSubscription.cancel();
    _globalQuerySubscription.cancel();
    return super.close();
  }
}

/// A viewer for the focal plane chart.
class FocalPlaneChartViewer extends StatefulWidget {
  /// The window to display the chart in.
  final WindowMetaData window;

  /// The bloc to manage the state of the chart.
  final FocalPlaneChartBloc bloc;

  /// The state of the entire workspace.
  /// (used to get the detector and global dayObs)
  final WorkspaceState workspace;

  const FocalPlaneChartViewer({
    super.key,
    required this.window,
    required this.bloc,
    required this.workspace,
  });

  @override
  FocalPlaneChartViewerState createState() => FocalPlaneChartViewerState();
}

/// The state of the [FocalPlaneChartViewer].
class FocalPlaneChartViewerState extends State<FocalPlaneChartViewer> {
  WindowMetaData get window => widget.window;
  WorkspaceState get workspace => widget.workspace;

  late final void Function(ColorbarState) _colorbarSubscription;

  /// We use a special editor for the series in a focal plane chart.
  Future<void> _editSeries(BuildContext context, SeriesInfo series) async {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    developer.log("New series fields: ${series.fields}", name: "rubin_chart.core.chart.dart");
    DatabaseSchema schema = DataCenter().databases[workspace.info!.instrument!.schema]!;
    SchemaField field;
    if (series.fields.isNotEmpty) {
      field = series.fields.values.first;
    } else {
      field = DataCenter().databases.values.first.tables[kCcdTables.last]!.fields.values.first;
    }

    final chartBloc = context.read<FocalPlaneChartBloc>();

    return showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: FocalPlaneColumnEditor(
          theme: workspace.theme,
          initialValue: field,
          databaseSchema: schema,
          chartBloc: chartBloc,
          workspace: workspace,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _colorbarSubscription = (ColorbarState state) {
      if (mounted) {
        setState(() {});
      }
    };
    widget.bloc.state.colorbarController.subscribe(_colorbarSubscription);
  }

  @override
  void dispose() {
    // Unsubscribe from the colorbar controller
    widget.bloc.state.colorbarController.unsubscribe(_colorbarSubscription);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<FocalPlaneChartBloc>.value(
      value: widget.bloc,
      child: BlocBuilder<FocalPlaneChartBloc, FocalPlaneChartState>(
        builder: (BuildContext context, FocalPlaneChartState state) {
          String columnName = "chart column";
          if (state.series.fields.isNotEmpty) {
            columnName = state.series.fields.values.first.name;
          }

          // Extract the data ID and the data
          String dayObsStr = "dayObs";
          String seqNumStr = "seqNum";
          Map<int, Color>? colors;
          if (state.dataIds.isNotEmpty) {
            DataId dataId = state.dataIds[state.dataIndex];
            dayObsStr = formatObsDate(dataId.dayObs);
            seqNumStr = dataId.seqNum.toString();
            colors = {};
            for (int detector in state.data[dataId]!.keys) {
              double value = state.dataAxis.toDouble(state.data[dataId]![detector]!);
              colors[detector] = state.colorbarController.getColor(value);
            }
          }

          return ResizableWindow(
            info: window,
            toolbar: Row(
              children: [
                Tooltip(
                  message: "Change the chart column",
                  child: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.green),
                    onPressed: () {
                      _editSeries(context, state.series);
                    },
                  ),
                ),
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
                        context.read<WorkspaceBloc>().add(RemoveWindowEvent(window.id));
                      },
                    ),
                  ),
                ),
              ],
            ),
            title: null,
            child: SizedBox(
              width: window.size.width,
              height: window.size.height,
              child: Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.grey[300],
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Text(dayObsStr),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.grey[300],
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Text(seqNumStr),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: Colors.grey[300],
                          ),
                          padding: const EdgeInsets.all(2),
                          child: Text(columnName),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: window.size.width - 30,
                            child: FocalPlaneViewer(
                              window: window,
                              instrument: workspace.instrument!,
                              selectedDetector: workspace.detector,
                              workspace: workspace,
                              detectorColors: colors,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Tooltip(
                            message: "Update colorbar",
                            waitDuration: const Duration(milliseconds: 1000),
                            child: SizedBox(
                              width: 50,
                              child: ColorbarSlider(
                                controller: state.colorbarController,
                                onChanged: (values) {
                                  developer.log('Values changed: $values',
                                      name: "rubinTV.visualization.focal_plane.chart");
                                },
                                orientation: ColorbarOrientation.vertical,
                                showLabels: true,
                              ),
                            )),
                        const SizedBox(width: 60),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    width: window.size.width,
                    child: Row(children: [
                      Tooltip(
                          message: "Animate selected data IDs",
                          child: SizedBox(
                            width: 50,
                            child: IconButton(
                              icon: state.isPlaying ? const Icon(Icons.pause) : const Icon(Icons.play_arrow),
                              onPressed: () {
                                if (!state.isPlaying) {
                                  context.read<FocalPlaneChartBloc>().add(FocalPlaneStartTimerEvent());
                                } else {
                                  context.read<FocalPlaneChartBloc>().add(FocalPlaneStopTimerEvent());
                                }
                              },
                            ),
                          )),
                      const SizedBox(width: 10),
                      Tooltip(
                          message: "Previous data ID",
                          child: Material(
                            color: Colors.grey[300],
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                if (state.dataIndex > 0) {
                                  context
                                      .read<FocalPlaneChartBloc>()
                                      .add(FocalPlaneUpdateDataIndexEvent(state.dataIndex - 1));
                                }
                              },
                            ),
                          )),
                      Expanded(
                        child: Slider(
                          value: state.dataIndex.toDouble(),
                          min: 0,
                          max: state.dataIds.isNotEmpty ? state.dataIds.length.toDouble() - 1 : 2,
                          divisions: state.dataIds.isNotEmpty ? state.dataIds.length - 1 : 2,
                          label: state.dataIndex.round().toString(),
                          onChanged: (value) {
                            context
                                .read<FocalPlaneChartBloc>()
                                .add(FocalPlaneUpdateDataIndexEvent(value.round().toInt()));
                          },
                        ),
                      ),
                      Tooltip(
                          message: "Next data ID",
                          child: Material(
                            color: Colors.grey[300],
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                if (state.dataIndex < state.dataIds.length - 1) {
                                  context
                                      .read<FocalPlaneChartBloc>()
                                      .add(FocalPlaneUpdateDataIndexEvent(state.dataIndex + 1));
                                }
                              },
                            ),
                          )),
                    ]),
                  ),
                  SizedBox(
                    width: window.size.width,
                    child: Row(
                      children: [
                        const Text("Playback speed"),
                        Expanded(
                          child: Slider(
                            value: state.playbackSpeed,
                            min: 0.1,
                            max: 10,
                            divisions: 100,
                            onChanged: (value) {
                              context
                                  .read<FocalPlaneChartBloc>()
                                  .add(FocalPlaneUpdatePlaybackSpeedEvent(value));
                            },
                          ),
                        ),
                        const SizedBox(width: 20),
                        Tooltip(
                            message: "Loop playback",
                            child: IconButton(
                              icon: const Icon(Icons.loop),
                              color: state.loopPlayback ? Colors.green : Colors.grey,
                              onPressed: () {
                                context.read<FocalPlaneChartBloc>().add(FocalPlaneToggleLoopEvent());
                              },
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
