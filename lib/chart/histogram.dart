import 'package:flutter/material.dart';
import 'package:rubintv_visualization/chart/axis.dart';
import 'package:rubintv_visualization/chart/cartesian.dart';
import 'package:rubintv_visualization/chart/chart.dart';
import 'package:rubintv_visualization/chart/legend.dart';
import 'package:rubintv_visualization/chart/marker.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/window.dart';

enum HistogramAggregation {
  count,
  sum,
  mean,
  median;

  String get axisName => toString().split(".").last;
}

class HistogramSeries extends Series {
  final HistogramAggregation aggregation;
  final int nBins;

  HistogramSeries({
    required super.id,
    required super.name,
    required super.fields,
    required super.chart,
    super.marker,
    super.errorBars,
    super.query,
    required this.aggregation,
    required this.nBins,
  });

  @override
  HistogramSeries copyWith({
    UniqueId? id,
    String? name,
    List<SchemaField>? fields,
    Chart? chart,
    MarkerSettings? marker,
    ErrorBarSettings? errorBars,
    Query? query,
    HistogramAggregation? aggregation,
    int? nBins,
  }) =>
      HistogramSeries(
        id: id ?? this.id,
        name: name ?? this.name,
        fields: fields ?? this.fields,
        chart: chart ?? this.chart,
        marker: marker ?? this.marker,
        errorBarSettings: errorBars ?? this.errorBars,
        query: query ?? this.query,
        aggregation: aggregation ?? this.aggregation,
        nBins: nBins ?? this.nBins,
      );
}

class Histogram extends Chart {
  Histogram({
    required super.id,
    required super.offset,
    super.title,
    required super.size,
    required super.series,
    required super.axes,
    required super.legend,
    required super.useGlobalQuery,
  });

  @override
  Chart copyWith({
    UniqueId? id,
    Offset? offset,
    Size? size,
    String? title,
    Map<UniqueId, Series>? series,
    List<PlotAxis?>? axes,
    ChartLegend? legend,
    bool? useGlobalQuery,
  }) =>
      Histogram(
        id: id ?? this.id,
        offset: offset ?? this.offset,
        size: size ?? this.size,
        title: title ?? this.title,
        series: series ?? this.series,
        axes: axes ?? this.axes,
        legend: legend ?? this.legend,
        useGlobalQuery: useGlobalQuery ?? this.useGlobalQuery,
      );

  /// Create the internal chart, not including the [ChartLegend].
  @override
  Widget createInternalChart({
    required AppTheme theme,
    required DataCenter dataCenter,
    required Size size,
    required WindowUpdateCallback dispatch,
  }) {
    String xLabel1 = "x-axis";
    String yLabel1 = "y-axis";
    if (axes.every((e) => e != null)) {
      xLabel1 = axes[0]!.label;
      yLabel1 = axes[1]!.label;
    }

    List<Map<String, dynamic>> seriesData = [];
    for (Series s in series.values) {
      List<Map<String, dynamic>>? _seriesData = dataCenter.getSeriesData(s.id);
      if (_seriesData != null) {
        print("found data!");
        seriesData.addAll(_seriesData);
      } else {
        print("no data found for ${s.id}!, ${dataCenter.data.keys}");
      }
    }

    late Widget plot;
    if (seriesData.isEmpty) {
      plot = Container();
    } else {
      /*plot = graphic.Chart(
        data: seriesData,
        variables: {
          "x": graphic.Variable(
            accessor: (Map<String, dynamic> d) => d[series.values.first.fields[0].name] as String,
          ),
          "y": graphic.Variable(
            accessor: (Map<String, dynamic> d) => d["value"] as num,
          ),
          "series": graphic.Variable(accessor: (Map<String, dynamic> d) => d["series"] as String),
        },
        marks: [
          graphic.IntervalMark(
            position: graphic.Varset("x") * graphic.Varset("y") / graphic.Varset("series"),
            size: graphic.SizeEncode(value: 10),
            /*color: graphic.ColorEncode(
              variable: "series",
              values: [...defaultColorCycle, ...defaultColorCycle, ...defaultColorCycle],
              updaters: {
                "choose": {true: (_) => Colors.red}
              },
            ),*/
          ),
        ],
        axes: [
          graphic.Defaults.horizontalAxis..tickLine = graphic.TickLine(),
          graphic.Defaults.verticalAxis,
        ],
        selections: {'tap': graphic.PointSelection(dim: graphic.Dim.x)},
      );*/
    }

    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomMultiChildLayout(
        delegate: CartesianPlotLayoutDelegate(),
        children: [
          LayoutId(
              id: CartesianLayoutElement.yAxisLeft,
              child: RotatedBox(
                quarterTurns: -1,
                child: Text(yLabel1, style: theme.axisLabelStyle),
              )),
          LayoutId(
            id: CartesianLayoutElement.xAxisBottom,
            child: Text(xLabel1, style: theme.axisLabelStyle),
          ),
          LayoutId(
              id: CartesianLayoutElement.plot,
              child: Container(
                //decoration: const BoxDecoration(color: Colors.blue),
                child: plot,
              )),
        ],
      ),
    );
  }

  /// Create a new empty Series for this [Chart].
  @override
  Series nextSeries({required DataCenter dataCenter}) {
    DataSource database = dataCenter.databases.values.first;
    Schema table = database.tables.values.first;
    UniqueId newId = UniqueId.next();
    print("adding a new Series with $newId");
    return Series(
      id: newId,
      name: "Series $newId",
      fields: table.fields.values.toList().sublist(0, 1),
      chart: this,
    );
  }

  @override
  int get nMaxAxes => 1;
}
