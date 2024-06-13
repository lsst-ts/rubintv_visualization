import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/series.dart';
import 'package:rubintv_visualization/workspace/toolbar.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// Tools for selecting unique sources.
enum MultiSelectionTool {
  select(Icons.touch_app, CursorAction.select),
  drillDown(Icons.query_stats, CursorAction.drillDown),
  dateTimeSelect(Icons.calendar_month_outlined, CursorAction.dateTimeSelect),
  ;

  final IconData icon;
  final CursorAction cursorAction;

  const MultiSelectionTool(this.icon, this.cursorAction);
}

class UpdateMultiSelect extends ToolbarAction {
  final MultiSelectionTool tool;
  final UniqueId chartId;

  UpdateMultiSelect(this.tool, this.chartId);
}

class UpdateChartBinsAction extends ToolbarAction {
  final UniqueId chartId;
  final int nBins;

  UpdateChartBinsAction({
    required this.chartId,
    required this.nBins,
  });
}

/// The type of chart to display.
enum InteractiveChartTypes {
  histogram,
  box,
  cartesianScatter,
  polarScatter,
  combination,
}

class CreateSeriesAction extends UiAction {
  final SeriesInfo series;

  CreateSeriesAction({
    required this.series,
  });
}

/// Persistable information to generate a chart
abstract class ChartWindow extends Window {
  final Map<SeriesId, SeriesInfo> _series;
  final Legend? legend;
  final List<ChartAxisInfo> _axisInfo;

  final InteractiveChartTypes chartType;

  /// Whether or not to use the global query for all series in this [ChartWindow].
  final bool useGlobalQuery;

  final List<GlobalKey> childKeys;

  ChartWindow({
    super.key,
    required super.id,
    required super.offset,
    super.title,
    required super.size,
    required Map<SeriesId, SeriesInfo> series,
    required List<ChartAxisInfo> axisInfo,
    required this.legend,
    required this.useGlobalQuery,
    required this.chartType,
    required this.childKeys,
  })  : _series = Map<SeriesId, SeriesInfo>.unmodifiable(series),
        _axisInfo = List<ChartAxisInfo>.unmodifiable(axisInfo);

  bool get useSelectionController;

  bool get useDrillDownController;

  /// Return a copy of the internal [Map] of [SeriesInfo], to prevent updates.
  Map<SeriesId, SeriesInfo> get series => {..._series};

  /// Return a copy of the internal [List] of [ChartAxisInfo], to prevent updates.
  List<ChartAxisInfo?> get axes => [..._axisInfo];

  static ChartWindow fromChartType({
    required UniqueId id,
    required Offset offset,
    required Size size,
    required InteractiveChartTypes chartType,
    List<GlobalKey>? childKeys,
  }) {
    List<ChartAxisInfo> axisInfo = [];
    childKeys ??= [GlobalKey()];
    switch (chartType) {
      case InteractiveChartTypes.histogram || InteractiveChartTypes.box:
        axisInfo = [
          ChartAxisInfo(
            label: "<x>",
            axisId: AxisId(AxisLocation.bottom),
          ),
        ];
        return BinnedChartWindow(
          id: id,
          offset: offset,
          size: size,
          series: {},
          axisInfo: axisInfo,
          legend: Legend(),
          useGlobalQuery: true,
          chartType: chartType,
          childKeys: childKeys,
          nBins: 20,
          tool: MultiSelectionTool.drillDown,
        );
      case InteractiveChartTypes.cartesianScatter:
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
        return ScatterChartWindow(
          id: id,
          offset: offset,
          size: size,
          series: {},
          axisInfo: axisInfo,
          legend: Legend(),
          useGlobalQuery: true,
          chartType: chartType,
          childKeys: childKeys,
          tool: MultiSelectionTool.select,
        );
      case InteractiveChartTypes.polarScatter:
        axisInfo = [
          ChartAxisInfo(
            label: "<r>",
            axisId: AxisId(AxisLocation.radial),
          ),
          ChartAxisInfo(
            label: "<θ>",
            axisId: AxisId(AxisLocation.angular),
          ),
        ];
        return ScatterChartWindow(
          id: id,
          offset: offset,
          size: size,
          series: {},
          axisInfo: axisInfo,
          legend: Legend(),
          useGlobalQuery: true,
          chartType: chartType,
          childKeys: childKeys,
          tool: MultiSelectionTool.select,
        );
      case InteractiveChartTypes.combination:
        throw UnimplementedError("Combination charts have not yet been implemented.");
    }
  }

  @override
  ChartWindow copyWith({
    UniqueId? id,
    Offset? offset,
    Size? size,
    String? title,
    Map<SeriesId, SeriesInfo>? series,
    List<ChartAxisInfo>? axisInfo,
    Legend? legend,
    bool? useGlobalQuery,
    InteractiveChartTypes? chartType,
  });

  ChartInfo _internalBuildChartInfo({required List<Series> allSeries});

  ChartInfo buildChartInfo(WorkspaceViewerState workspace) {
    List<Series> allSeries = [];
    for (SeriesInfo seriesInfo in _series.values) {
      Series? series = seriesInfo.toSeries(workspace.dataCenter);
      if (series != null) {
        allSeries.add(series);
      }
    }

    return _internalBuildChartInfo(allSeries: allSeries);
  }

  /// Create a new [Widget] to display in a [WorkspaceViewer].
  @override
  Widget createWidget(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    SelectionController? selectionController = workspace.selectionController;
    SelectionController? drillDownController = workspace.drillDownController;
    if (chartType == InteractiveChartTypes.histogram) {
      if (!useDrillDownController) {
        drillDownController = null;
      }
      if (!useSelectionController) {
        selectionController = null;
      }
    }

    return RubinChart(
      key: key,
      info: buildChartInfo(workspace),
      selectionController: selectionController,
      drillDownController: drillDownController,
    );
  }

  /// Whether or not at least one [PlotAxis] has been set.
  bool get hasAxes => axes.isNotEmpty;

  /// Whether or not at least one [Series] has been initialized.
  bool get hasSeries => _series.isNotEmpty;

  /// Check if a series is compatible with this chart.
  /// Any mismatched columns have their indices returned.
  List<AxisId>? canAddSeries({
    required SeriesInfo series,
    required DataCenter dataCenter,
  }) {
    final List<AxisId> mismatched = [];
    // Check that the series has the correct number of columns and axes
    if (series.fields.length != axes.length) {
      developer.log("bad axes", name: "rubin_chart.core.chart.dart");
      return null;
    }
    for (AxisId sid in series.fields.keys) {
      SchemaField field = series.fields[sid]!;
      for (SeriesInfo otherSeries in _series.values) {
        SchemaField? otherField = otherSeries.fields[sid];
        if (otherField == null) {
          developer.log("missing field $sid", name: "rubin_chart.core.chart.dart");
          mismatched.add(sid);
        } else {
          // Check that the new series is compatible with the existing series
          if (!dataCenter.isFieldCompatible(field, otherField)) {
            developer.log(
              "Incompatible fields $otherField and $field",
              name: "rubin_chart.core.chart.dart",
            );
            mismatched.add(sid);
          }
        }
      }
    }
    return mismatched;
  }

  /// Update [ChartWindow] when [Series] is updated.
  ChartWindow addSeries({
    required SeriesInfo series,
  }) {
    Map<SeriesId, SeriesInfo> newSeries = {..._series};
    newSeries[series.id] = series;
    return copyWith(series: newSeries);
  }

  BigInt get nextSeriesId {
    BigInt maxId = BigInt.zero;
    for (SeriesId sid in _series.keys) {
      if (sid.id > maxId) {
        maxId = sid.id;
      }
    }
    return maxId + BigInt.one;
  }

  /// Create a new empty Series for this [ChartWindow].
  SeriesInfo nextSeries({required DataCenter dataCenter}) {
    SeriesId sid = SeriesId(windowId: id, id: nextSeriesId);
    DatabaseSchema database = dataCenter.databases.values.first;
    TableSchema table = database.tables.values.first;
    Map<AxisId, SchemaField> fields = {};
    for (int i = 0; i < axes.length; i++) {
      fields[axes[i]!.axisId] = table.fields.values.toList()[i];
    }
    return SeriesInfo(
      id: sid,
      name: "Series-${id.id}",
      axes: axes.map((ChartAxisInfo? info) => info!.axisId).toList(),
      fields: fields,
    );
  }

  int get nMaxAxes {
    if (chartType == InteractiveChartTypes.histogram) {
      return 1;
    } else if (chartType == InteractiveChartTypes.cartesianScatter) {
      return 2;
    } else if (chartType == InteractiveChartTypes.polarScatter) {
      return 2;
    } else if (chartType == InteractiveChartTypes.combination) {
      return 2;
    }
    throw UnimplementedError("Unknown chart type: $chartType");
  }

  Future<void> _editSeries(BuildContext context, SeriesInfo series, isNew) async {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: SeriesEditor(
          theme: workspace.theme,
          series: series,
          isNew: isNew,
          dataCenter: workspace.dataCenter,
          dispatch: workspace.dispatch,
        ),
      ),
    );
  }

  List<Widget> getDefaultTools(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return [
      Tooltip(
        message: "Add a new series to the chart",
        child: IconButton(
          icon: const Icon(Icons.format_list_bulleted_add, color: Colors.green),
          onPressed: () {
            SeriesInfo newSeries = nextSeries(dataCenter: workspace.dataCenter);
            workspace.dispatch(CreateSeriesAction(series: newSeries));
            _editSeries(context, newSeries, true);
          },
        ),
      ),
      Tooltip(
        message: "Use the global query",
        child: IconButton(
          icon: useGlobalQuery
              ? const Icon(Icons.travel_explore, color: Colors.green)
              : const Icon(Icons.public_off, color: Colors.grey),
          onPressed: () {
            workspace.dispatch(UpdateChartGlobalQueryAction(
              useGlobalQuery: !useGlobalQuery,
              dataCenter: workspace.dataCenter,
              chartId: id,
            ));
          },
        ),
      ),
      const SizedBox(width: 10),
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
              workspace.dispatch(RemoveWindowAction(this));
            },
          ),
        ),
      )
    ];
  }
}

class ScatterChartWindow extends ChartWindow {
  final MultiSelectionTool tool;

  ScatterChartWindow({
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
  ScatterChartWindow copyWith({
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
      ScatterChartWindow(
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

class BinnedChartWindow extends ChartWindow {
  final int nBins;
  final MultiSelectionTool tool;
  final TextEditingController _binController = TextEditingController();

  BinnedChartWindow({
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
  BinnedChartWindow copyWith({
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
      BinnedChartWindow(
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
  final ChartWindow chartWindow;

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
