import 'package:flutter/widgets.dart';
import 'package:rubintv_visualization/chart/mapping.dart';
import 'package:rubintv_visualization/editors/series.dart';

class CartesianPlot extends CustomPainter {
  final List<Axis> axes;
  final Series series;
  final Mapping mapping;
  final List<List<Widget>>? axisLabels;

  CartesianPlot({
    required this.axes,
    required this.series,
    required this.mapping,
    this.axisLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class ScatterPlot extends StatelessWidget {
  final List<Axis> axes;
  final Series series;
  final Mapping mapping;
  final List<num> x;
  final List<num> y;
  final List<List<Widget>>? axisLabels;

  const ScatterPlot({
    super.key,
    required this.axes,
    required this.series,
    required this.mapping,
    required this.x,
    required this.y,
    this.axisLabels,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CartesianPlot(
        axes: axes,
        series: series,
        mapping: mapping,
        axisLabels: axisLabels,
      ),
    );
  }
}
