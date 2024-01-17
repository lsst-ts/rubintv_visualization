import 'package:flutter/widgets.dart';
import 'package:rubintv_visualization/chart/axis.dart';
import 'package:rubintv_visualization/chart/marker.dart';
import 'package:rubintv_visualization/chart/projection.dart';
import 'package:rubintv_visualization/chart/tick.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// Paint a 2D [Series] in a plot.
class SeriesPainter extends CustomPainter {
  /// The axes of the plot, used to project the markers onto the plot.
  final List<PlotAxis> axes;

  /// The marker style used for the series.
  final MarkerSettings marker;

  /// The error bar style used for the series.
  final ErrorBarSettings? errorBars;

  /// The projection used for the series.
  ProjectionInitializer projectionInitializer;

  /// The x coordinates of the data points.
  final SeriesData data;

  /// Offset from the lower left to make room for labels.
  EdgeInsets tickLabelMargin;

  SeriesPainter({
    required this.axes,
    required this.marker,
    required this.errorBars,
    required this.projectionInitializer,
    required this.data,
    required this.tickLabelMargin,
  });

  /// Paint the series on the [Canvas].
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate the projection used for all points in the series
    Projection<num> projection = projectionInitializer(
      axes: axes,
      plotSize: size,
    );

    // Since all of the objects in the series use the same marker style,
    // we can calculate the [Paint] objects once and reuse them.
    Color? fillColor = marker.color;
    Color? edgeColor = marker.edgeColor;
    Paint? paintFill;
    Paint? paintEdge;
    if (fillColor != null) {
      paintFill = Paint()..color = fillColor;
    }
    if (edgeColor != null) {
      paintEdge = Paint()
        ..color = edgeColor
        ..strokeWidth = marker.size / 10
        ..style = PaintingStyle.stroke;
    }

    Size plotSize = Size(size.width - tickLabelMargin.left - tickLabelMargin.right,
        size.height - tickLabelMargin.top - tickLabelMargin.bottom);
    Rect plowWindow = Offset(tickLabelMargin.left, tickLabelMargin.bottom) & plotSize;

    for (int i = 0; i < data.length; i++) {
      Offset point = projection.project(coordinates: data.toCoordinates(i), axes: axes);
      if (plowWindow.contains(point)) {
        marker.paint(canvas, paintFill, paintEdge, point);
        // TODO: draw error bars
      }
    }
  }

  @override
  bool shouldRepaint(SeriesPainter oldDelegate) {
    /// TODO: add checks for marker, errorbar, axes changes
    return oldDelegate.data != data && oldDelegate.tickLabelMargin != tickLabelMargin;
  }
}

/// Paint the frame, axes, and tick marks of a plot.
class AxisPainter extends CustomPainter {
  final List<PlotAxis> axes;
  final List<Ticks?> ticks;
  final List<List<TextPainter>?> tickLabels;
  final List<Color> colorCycle;
  final PlotTheme theme;

  /// Offset from the lower left to make room for labels.
  Offset labelOffset;

  AxisPainter({
    required this.axes,
    required this.ticks,
    required this.tickLabels,
    required this.colorCycle,
    required this.labelOffset,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // TODO: draw the grid

    // TODO: draw the ticks

    // TODO: draw the tick labels

    if (theme.frameColor != null) {
      // Draw the frame
      Paint framePaint = Paint()
        ..color = theme.frameColor!
        ..strokeWidth = theme.frameLineThickness;
      canvas.drawRect(labelOffset & size, framePaint);
    }
  }

  @override
  bool shouldRepaint(AxisPainter oldDelegate) {
    return oldDelegate.axes != axes;
  }
}

/// A scatter plot where all points are projected onto two dimensional axes.
class ScatterPlot extends StatelessWidget {
  final List<PlotAxis> axes;
  final List<Series> series;
  final Map<UniqueId, SeriesData> data;
  final List<Color> colorCycle;
  final PlotTheme theme;
  final ProjectionInitializer projectionInitializer;

  const ScatterPlot({
    super.key,
    required this.axes,
    required this.series,
    required this.data,
    required this.colorCycle,
    required this.theme,
    required this.projectionInitializer,
  });

  @override
  Widget build(BuildContext context) {
    // TODO: Draw and layout the axis labels
    List<List<TextPainter>?> axisLabels = List.from((axes.map((axis) => null)));

    List<Widget> children = [
      CustomPaint(
        painter: AxisPainter(
          axes: axes,
          ticks: List.from((axes.map((axis) => null))), // TODO: calculate ticks
          tickLabels: axisLabels,
          colorCycle: colorCycle,
          labelOffset: Offset.zero,
          theme: theme,
        ),
      ),
    ];

    int nextColorIndex = 0;

    for (int i = 0; i < series.length; i++) {
      Series seriesItem = series[i];
      late MarkerSettings marker;
      if (seriesItem.marker != null) {
        marker = seriesItem.marker!;
      } else {
        if (nextColorIndex >= theme.colorCycle.length) {
          nextColorIndex = 0;
        }
        marker = MarkerSettings(color: theme.colorCycle[nextColorIndex++]);
      }
      children.add(Expanded(
        child: CustomPaint(
          painter: SeriesPainter(
            axes: axes,
            marker: marker,
            errorBars: seriesItem.errorBars,
            projectionInitializer: projectionInitializer,
            data: data[seriesItem.id]!,
            tickLabelMargin: EdgeInsets.zero, // TODO: calculate tick label margin from ticks
          ),
        ),
      ));
    }

    return Stack(children: children);
  }
}
