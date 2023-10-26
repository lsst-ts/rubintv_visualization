import 'package:flutter/material.dart';
import 'package:graphic/graphic.dart' as graphic;
import 'package:rubintv_visualization/chart/axis.dart';
import 'package:rubintv_visualization/chart/chart.dart';
import 'package:rubintv_visualization/chart/legend.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/window.dart';

enum _LayoutElement {
  title,
  legend,
  xAxisBottom,
  xAxisTop,
  yAxisLeft,
  yAxisRight,
  plot,
}

class _CartesianPlotLayoutDelegate extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final BoxConstraints constraints = BoxConstraints.loose(size);

    // Step 1: Layout the rotated vertical axis label.
    final Size sizeY1 = layoutChild(_LayoutElement.yAxisLeft, constraints);
    // Step 2: Layout A (the horizontal axis label)
    final Size sizeX1 = layoutChild(_LayoutElement.xAxisBottom, constraints);
    // Step 3: Layout C (the main plot widget) with the remaining space
    final double plotWidth = size.width - sizeY1.width;
    final double plotHeight = size.height - sizeX1.height;
    layoutChild(_LayoutElement.plot,
        constraints.copyWith(maxWidth: plotWidth, maxHeight: plotHeight));

    // Step 4: position the elements
    Offset y1Offset = Offset(0, (plotHeight - sizeY1.height) / 2);
    Offset plotOffset = Offset(sizeY1.width, 0);
    Offset x1Offset = Offset(sizeY1.width + (plotWidth - sizeX1.width) / 2,
        size.height - sizeX1.height);
    positionChild(_LayoutElement.yAxisLeft, y1Offset);
    positionChild(_LayoutElement.xAxisBottom, x1Offset);
    positionChild(_LayoutElement.plot, plotOffset);
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) => false;
}

class ScatterChart extends Chart {
  ScatterChart({
    required super.id,
    required super.offset,
    super.title,
    required super.size,
    required super.series,
    required super.axes,
    required super.legend,
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
  }) =>
      ScatterChart(
        id: id ?? this.id,
        offset: offset ?? this.offset,
        size: size ?? this.size,
        title: title ?? this.title,
        series: series ?? this.series,
        axes: axes ?? this.axes,
        legend: legend ?? this.legend,
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
      plot = graphic.Chart(
        data: seriesData,
        variables: {
          "x": graphic.Variable(
            accessor: (Map<String, dynamic> d) =>
                d[series.values.first.fields[0].name] as num,
          ),
          "y": graphic.Variable(
            accessor: (Map<String, dynamic> d) =>
                d[series.values.first.fields[1].name] as num,
          ),
          "series": graphic.Variable(
              accessor: (Map<String, dynamic> d) => d["series"] as String),
        },
        marks: [
          graphic.PointMark(
            position: graphic.Varset("x") *
                graphic.Varset("y") /
                graphic.Varset("series"),
            size: graphic.SizeEncode(value: 15),
            color: graphic.ColorEncode(
              variable: "series",
              values: [...defaultColorCycle, ...defaultColorCycle],
              updaters: {
                "choose": {true: (_) => Colors.red}
              },
            ),
          ),
        ],
        axes: [
          graphic.Defaults.horizontalAxis,
          graphic.Defaults.verticalAxis,
        ],
        coord: graphic.RectCoord(
          horizontalRange: [0.05, 0.95],
          verticalRange: [0.05, 0.95],
          horizontalRangeUpdater: graphic.Defaults.horizontalRangeEvent,
          verticalRangeUpdater: graphic.Defaults.verticalRangeEvent,
        ),
        selections: {'choose': graphic.PointSelection(toggle: true)},
      );
    }

    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomMultiChildLayout(
        delegate: _CartesianPlotLayoutDelegate(),
        children: [
          LayoutId(
              id: _LayoutElement.yAxisLeft,
              child: RotatedBox(
                quarterTurns: -1,
                child: Text(yLabel1, style: theme.axisLabelStyle),
              )),
          LayoutId(
            id: _LayoutElement.xAxisBottom,
            child: Text(xLabel1, style: theme.axisLabelStyle),
          ),
          LayoutId(
              id: _LayoutElement.plot,
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
    Database database = dataCenter.databases.values.first;
    Schema table = database.tables.values.first;
    UniqueId newId = UniqueId.next();
    print("adding a new Series with $newId");
    return Series(
      id: newId,
      name: "Series $newId",
      fields: table.fields.values.toList().sublist(0, 2),
      chart: this,
    );
  }

  @override
  int get nMaxAxes => 2;
}
