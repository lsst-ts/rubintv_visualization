import "dart:math" as math;
import 'package:flutter/material.dart';

enum MarkerTypes {
  circle,
  rectangle,
  unicode,
}

class MarkerSettings {
  final double size;
  final MarkerTypes type;
  final Color? color;
  final Color? edgeColor;

  const MarkerSettings({
    this.size = 10,
    this.color = Colors.black,
    this.edgeColor = Colors.white,
    this.type = MarkerTypes.circle,
  });

  MarkerSettings copyWith({
    double? size,
    MarkerTypes? type,
    Color? color,
    Color? edgeColor,
  }) =>
      MarkerSettings(
        size: size ?? this.size,
        type: type ?? this.type,
        color: color ?? this.color,
        edgeColor: edgeColor ?? this.edgeColor,
      );

  /// Paint a marker on the [Canvas] at a given [math.Point].
  void paint(Canvas canvas, Paint? paintFill, Paint? paintEdge, Offset point) {
    // TODO: support marker types other than circles
    if (type == MarkerTypes.circle) {
      if (paintFill != null) {
        canvas.drawCircle(Offset(point.dx, point.dy), 5, paintFill);
      }
      if (paintEdge != null) {
        canvas.drawCircle(Offset(point.dx, point.dy), 5, paintEdge);
      }
    } else {
      throw UnimplementedError("Only circle markers are supported at this time");
    }
  }
}

class ErrorBarSettings {
  final double width;
  final double headSize;
  final Color color;

  const ErrorBarSettings({
    this.width = 2,
    this.color = Colors.black,
    this.headSize = 20,
  });

  ErrorBarSettings copyWith({
    double? width,
    Color? color,
    double? headSize,
  }) =>
      ErrorBarSettings(
        width: width ?? this.width,
        color: color ?? this.color,
        headSize: headSize ?? this.headSize,
      );
}

// TODO: replace this class with one that will draw the same marker element that is drawn in the chart
class Marker extends StatelessWidget {
  final double size;
  final MarkerTypes markerType;
  final Color? color;
  final Color? edgeColor;
  final double edgeWidth;

  const Marker({
    super.key,
    required this.size,
    required this.color,
    this.edgeColor,
    this.edgeWidth = 1,
    this.markerType = MarkerTypes.circle,
  });

  @override
  Widget build(BuildContext context) {
    Widget result;

    if (markerType == MarkerTypes.circle) {
      result = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      );
    } else {
      throw UnimplementedError("Marker type $markerType has not yet been implemented");
    }
    return result;
  }
}
