import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/focal_plane/editor.dart';
import 'package:rubintv_visualization/focal_plane/slider.dart';
import 'package:rubintv_visualization/focal_plane/viewer.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';
import 'package:rubintv_visualization/workspace/window.dart';

const int kDefaultPlaybackSpeed = 500;
const double kPlaybackSpeedStep = 1.25;

ChartAxis _createEmptyAxis(ChartAxisInfo axisInfo, ChartTheme theme) {
  return NumericalChartAxis(
    info: axisInfo,
    bounds: const Bounds(0, 0),
    dataBounds: const Bounds(0, 0),
    ticks: AxisTicks(
      majorTicks: [],
      minorTicks: [],
      bounds: const Bounds(0, 0),
      tickLabels: [],
    ),
    theme: theme,
  );
}

String formatDate(int dateNumber) {
  String dateString = dateNumber.toString().padLeft(8, '0');
  return '${dateString.substring(0, 4)}-${dateString.substring(4, 6)}-${dateString.substring(6)}';
}

abstract class FocalPlaneChartEvent {}

class InitializeFocalPlaneChartEvent extends FocalPlaneChartEvent {
  final UniqueId id;
  final SeriesInfo series;
  final ChartAxis dataAxis;
  final ColorbarController colorbarController;
  final String? dayObs;

  InitializeFocalPlaneChartEvent({
    required this.id,
    required this.series,
    required this.dataAxis,
    required this.colorbarController,
    required this.dayObs,
  });
}

class FocalPlaneReceiveMessageEvent extends FocalPlaneChartEvent {
  final Map<String, dynamic> message;

  FocalPlaneReceiveMessageEvent(this.message);
}

class FocalPlaneUpdateColumnEvent extends FocalPlaneChartEvent {
  final SchemaField field;
  final String? dayObs;
  final Set<DataId> selected;

  FocalPlaneUpdateColumnEvent({
    required this.field,
    required this.dayObs,
    required this.selected,
  });
}

class FocalPlaneUpdateDataIndexEvent extends FocalPlaneChartEvent {
  final int index;

  FocalPlaneUpdateDataIndexEvent(this.index);
}

class FocalPlaneIncreaseDataIndexEvent extends FocalPlaneChartEvent {}

class FocalPlaneUpdatePlaybackSpeedEvent extends FocalPlaneChartEvent {
  final double speed;

  FocalPlaneUpdatePlaybackSpeedEvent(this.speed);
}

class FocalPlaneStartTimerEvent extends FocalPlaneChartEvent {}

class FocalPlaneStopTimerEvent extends FocalPlaneChartEvent {}

class FocalPlaneTickEvent extends FocalPlaneChartEvent {}

class FocalPlaneToggleLoopEvent extends FocalPlaneChartEvent {}

abstract class FocalPlaneChartState {}

class FocalPlaneChartStateInitial extends FocalPlaneChartState {}

class FocalPlaneChartStateLoaded extends FocalPlaneChartState {
  UniqueId id;
  SeriesInfo series;
  ChartAxis dataAxis;
  ChartAxisInfo detectorAxisInfo = ChartAxisInfo(label: "Detector", axisId: AxisId(AxisLocation.color));
  Map<DataId, Map<int, dynamic>> data;
  List<DataId> dataIds;
  int dataIndex;
  ColorbarController colorbarController;
  double playbackSpeed;
  bool isPlaying;
  bool loopPlayback;
  String? dayObs;

  FocalPlaneChartStateLoaded({
    required this.id,
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
  });

  FocalPlaneChartStateLoaded copyWith({
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
      FocalPlaneChartStateLoaded(
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

  AxisId get dataAxisId => dataAxis.info.axisId;
}

class FocalPlaneChartBloc extends Bloc<FocalPlaneChartEvent, FocalPlaneChartState> {
  late StreamSubscription _websocketSubscription;
  late StreamSubscription _globalQuerySubscription;
  Timer? _playTimer;
  Timer? _selectionTimer;

  FocalPlaneChartBloc() : super(FocalPlaneChartStateInitial()) {
    _websocketSubscription = WebSocketManager().messages.listen((message) {
      add(FocalPlaneReceiveMessageEvent(message));
    });

    ControlCenter().selectionController.subscribe((Set<Object> dataPoints) {
      if (this.state is! FocalPlaneChartStateLoaded) {
        return;
      }
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
      _selectionTimer?.cancel();
      _selectionTimer = Timer(const Duration(milliseconds: 500), () {
        add(FocalPlaneUpdateColumnEvent(
          field: state.series.fields.values.first,
          dayObs: state.dayObs,
          selected: dataPoints.map((e) => e as DataId).toSet(),
        ));
      });
    });

    _globalQuerySubscription = ControlCenter().globalQueryStream.listen((GlobalQuery? query) {
      if (state is FocalPlaneChartStateLoaded) {
        FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
        Set<DataId>? selected =
            ControlCenter().selectionController.selectedDataPoints.map((e) => e as DataId).toSet();
        if (selected.isEmpty) {
          selected = ControlCenter().drillDownController.selectedDataPoints.map((e) => e as DataId).toSet();
        }
        if (selected.isEmpty) {
          selected = null;
        }
        _fetchSeriesData(
            series: state.series, query: query?.query, dayObs: query?.dayObs, selected: selected);
      }
    });

    on<InitializeFocalPlaneChartEvent>((event, emit) {
      ColorbarController colorbarController = event.colorbarController;
      emit(FocalPlaneChartStateLoaded(
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

    on<FocalPlaneReceiveMessageEvent>((event, emit) {
      if (this.state is FocalPlaneChartStateInitial) {
        return;
      }
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;

      List<String>? splitId = event.message["requestId"]?.split(",");
      if (splitId == null || splitId.length != 2) {
        return;
      }
      UniqueId windowId = UniqueId.fromString(splitId[0]);

      if (event.message["type"] == "table columns" && windowId == state.id) {
        FocalPlaneChartStateLoaded? newState = _updateSeriesData(event);
        if (newState != null) {
          emit(newState);
        }
      }
    });

    on<FocalPlaneUpdateColumnEvent>((event, emit) {
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
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

      if (event.selected.isNotEmpty) {
        _fetchSeriesData(series: newSeries, selected: event.selected);
      } else if (event.dayObs != null) {
        _fetchSeriesData(series: newSeries, dayObs: event.dayObs);
      }

      emit(state.copyWith(series: newSeries));
    });

    on<FocalPlaneUpdateDataIndexEvent>((event, emit) {
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
      emit(state.copyWith(dataIndex: event.index));
    });

    on<FocalPlaneIncreaseDataIndexEvent>((event, emit) {
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
      if (state.dataIndex < state.dataIds.length - 1) {
        emit(state.copyWith(dataIndex: state.dataIndex + 1));
      }
    });

    on<FocalPlaneUpdatePlaybackSpeedEvent>((event, emit) {
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
      emit(state.copyWith(playbackSpeed: event.speed));
      if (state.isPlaying) {
        _createTimer();
      }
    });

    on<FocalPlaneStartTimerEvent>((event, emit) {
      _createTimer();
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
      int dataIndex = state.dataIndex;
      if (dataIndex == state.dataIds.length - 1) {
        dataIndex = 0;
      }
      emit(state.copyWith(isPlaying: true, dataIndex: dataIndex));
    });

    on<FocalPlaneStopTimerEvent>((event, emit) {
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
      _playTimer?.cancel();
      _playTimer = null;
      emit(state.copyWith(isPlaying: false));
    });

    on<FocalPlaneTickEvent>((event, emit) {
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
      if (state.dataIndex < state.dataIds.length - 1) {
        emit(state.copyWith(dataIndex: state.dataIndex + 1));
      } else if (state.loopPlayback) {
        emit(state.copyWith(dataIndex: 0));
      } else {
        _playTimer?.cancel();
        emit(state.copyWith(isPlaying: false));
      }
    });

    on<FocalPlaneToggleLoopEvent>((event, emit) {
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
      emit(state.copyWith(loopPlayback: !state.loopPlayback));
    });
  }

  void _createTimer() {
    FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
    _playTimer?.cancel();
    _playTimer = Timer.periodic(Duration(milliseconds: (kDefaultPlaybackSpeed / state.playbackSpeed).round()),
        (timer) {
      add(FocalPlaneTickEvent());
    });
  }

  FocalPlaneChartStateLoaded? _updateSeriesData(FocalPlaneReceiveMessageEvent event) {
    // Extract result
    FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
    int rows = event.message["content"]["data"].values.first.length;
    int columns = event.message["content"]["data"].length;
    developer.log("received $columns columns and $rows rows for ${event.message["requestId"]}",
        name: "rubin_chart.workspace");
    if (rows > 0) {
      Map<String, List<dynamic>> allData = Map<String, List<dynamic>>.from(
          event.message["content"]["data"].map((key, value) => MapEntry(key, List<dynamic>.from(value))));

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

  void _fetchSeriesData({
    required SeriesInfo series,
    Set<DataId>? selected,
    Query? query,
    String? dayObs,
  }) {
    WebSocketManager websocket = WebSocketManager();
    if (websocket.isConnected) {
      FocalPlaneChartStateLoaded state = this.state as FocalPlaneChartStateLoaded;
      websocket.sendMessage(LoadColumnsCommand.build(
        seriesId: series.id,
        fields: series.fields.values.toList(),
        query: query,
        useGlobalQuery: false,
        dayObs: dayObs,
        windowId: state.id,
        dataIds: selected,
      ).toJson());
    }
  }

  @override
  Future<void> close() {
    _websocketSubscription.cancel();
    return super.close();
  }
}

class FocalPlaneChartViewer extends StatefulWidget {
  final Window window;
  final WorkspaceState workspace;

  const FocalPlaneChartViewer({
    super.key,
    required this.window,
    required this.workspace,
  });

  @override
  FocalPlaneChartViewerState createState() => FocalPlaneChartViewerState();
}

class FocalPlaneChartViewerState extends State<FocalPlaneChartViewer> {
  Window get window => widget.window;
  WorkspaceState get workspace => widget.workspace;

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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (BuildContext context) {
        SeriesId sid = SeriesId(windowId: window.id, id: BigInt.zero);
        AxisId valueAxisId = AxisId(AxisLocation.right);
        AxisId detectorAxisId = AxisId(AxisLocation.color);
        Map<AxisId, SchemaField> fields = {};
        ChartAxisInfo axisInfo = ChartAxisInfo(
          label: "Focal Plane color axis",
          axisId: valueAxisId,
        );
        ChartAxis dataAxis = _createEmptyAxis(axisInfo, workspace.theme.chartTheme);

        SeriesInfo newSeries = SeriesInfo(
          id: sid,
          name: "Focal Plane Chart",
          axes: [valueAxisId, detectorAxisId],
          fields: fields,
        );

        ColorbarController colorbarController = ColorbarController(
          min: 0,
          max: 100,
          stops: {
            0: Colors.blue,
            100: Colors.red,
          },
        );

        colorbarController.subscribe((ColorbarState state) {
          setState(() {});
        });

        return FocalPlaneChartBloc()
          ..add(
            InitializeFocalPlaneChartEvent(
              id: window.id,
              series: newSeries,
              dataAxis: dataAxis,
              colorbarController: colorbarController,
              dayObs: getFormattedDate(workspace.dayObs),
            ),
          );
      },
      child: BlocBuilder<FocalPlaneChartBloc, FocalPlaneChartState>(
        builder: (BuildContext context, FocalPlaneChartState state) {
          if (state is FocalPlaneChartStateInitial) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          FocalPlaneChartStateLoaded fullState = state as FocalPlaneChartStateLoaded;

          String columnName = "chart column";
          if (fullState.series.fields.isNotEmpty) {
            columnName = fullState.series.fields.values.first.name;
          }

          String dayObsStr = "dayObs";
          String seqNumStr = "seqNum";
          Map<int, Color>? colors;
          if (fullState.dataIds.isNotEmpty) {
            DataId dataId = fullState.dataIds[fullState.dataIndex];
            dayObsStr = formatDate(dataId.dayObs);
            seqNumStr = dataId.seqNum.toString();
            colors = {};
            for (int detector in fullState.data[dataId]!.keys) {
              double value = fullState.dataAxis.toDouble(fullState.data[dataId]![detector]!);
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
                      _editSeries(context, fullState.series);
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
                        SizedBox(
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
                        ),
                        const SizedBox(width: 60),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    width: window.size.width,
                    child: Row(children: [
                      SizedBox(
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
                      ),
                      const SizedBox(width: 10),
                      Material(
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
                      ),
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
                      Material(
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
                      ),
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
                        IconButton(
                          icon: const Icon(Icons.loop),
                          color: state.loopPlayback ? Colors.green : Colors.grey,
                          onPressed: () {
                            context.read<FocalPlaneChartBloc>().add(FocalPlaneToggleLoopEvent());
                          },
                        ),
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
