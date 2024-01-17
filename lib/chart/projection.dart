import 'dart:math' as math;
import 'dart:ui';

import 'package:rubintv_visualization/chart/axis.dart';
import 'package:rubintv_visualization/utils.dart';

typedef ProjectionInitializer = Projection<num> Function({
  required List<PlotAxis> axes,
  required Size plotSize,
});

/// Conversion factor from degrees to radians.
const degToRadians = math.pi / 180;

/// Conversion factor from radians to degrees.
const radiansToDeg = 1 / degToRadians;

/// Transformation from [PlotAxis] plot coordinates to pixel coordinates for
/// either the x or y axis.
class PixelTransform {
  final double origin;
  final double scale;
  final double? invertSize;

  PixelTransform({
    required this.origin,
    required this.scale,
    this.invertSize,
  });

  /// Load a plot transformation for a given [PlotAxis].
  static PixelTransform fromAxis({
    required PlotAxis axis,
    required double plotSize,
    double? invertSize,
  }) {
    Bounds bounds = axis.bounds!;
    //bounds = axis.tickBounds!;
    return PixelTransform(
      origin: bounds.min.toDouble(),
      scale: plotSize / bounds.range,
      invertSize: invertSize,
    );
  }

  /// Convert a number from the axis coordinates to the pixel coordinates
  double map(num x) {
    double result = (x - origin) * scale;
    if (invertSize != null) {
      result = invertSize! - result;
    }
    return result;
  }

  /// Convert a number from pixel coordinates to axes coordinates
  double inverse(double x) {
    double result = x;
    if (invertSize != null) {
      result = invertSize! - result;
    }
    result = result / scale + origin;
    return result;
  }

  /// Two [PixelTransform]s are equal when their origin and scale are the same.
  /// This is used by  eg. [TickMarkPainter] to check whether or not a repaint is necessary.
  @override
  bool operator ==(Object other) => other is PixelTransform && other.origin == origin && other.scale == scale;

  /// Overriding the [==] operator also requires overriding the [hashCode].
  @override
  int get hashCode => Object.hash(origin, scale);

  @override
  String toString() => "PlotTransform(origin=$origin, scale=$scale)";
}

/// A projection from a set of axes, potentially multidimensional or
/// non-cartesian, to cartesian x and y coordinates in axis unit coordinates.
/// The additional [PixelTransform]s are used to convert from the axis coordinates
/// to pixel coordinates.
abstract class Projection<T> {
  /// Transform from cartesian x to plot x.
  final PixelTransform xTransform;

  /// Transform from cartesian y to plot y.
  final PixelTransform yTransform;

  const Projection({
    required this.xTransform,
    required this.yTransform,
  });

  Offset project({
    required List<T> coordinates,
    required List<PlotAxis> axes,
  });

  Offset map(List<T> coordinates);
}

/// A 2D projection
mixin Projection2D implements Projection<num> {
  @override
  Offset project({
    required List<num> coordinates,
    required List<PlotAxis> axes,
  }) {
    assert(coordinates.length == 2, "Projection2D requires two coordinates, got ${coordinates.length}");
    Offset projection = map(coordinates);
    double x = xTransform.map(projection.dx);
    double y = yTransform.map(projection.dy);
    return Offset(x, y);
  }

  @override
  Offset map(List<num> coordinates) {
    assert(coordinates.length == 2, "Projection2D requires two coordinates, got ${coordinates.length}");
    return Offset(coordinates[0].toDouble(), coordinates[1].toDouble());
  }
}

class CartesianProjection extends Projection<num> with Projection2D {
  const CartesianProjection({
    required super.xTransform,
    required super.yTransform,
  });

  static CartesianProjection fromAxes({
    required List<PlotAxis> axes,
    required Size plotSize,
  }) {
    assert(axes.length == 2, "CartesianProjection requires two axes, got ${axes.length}");
    PlotAxis xAxis = axes[0];
    PlotAxis yAxis = axes[1];
    double? xInvertSize = xAxis.isInverted ? plotSize.width : null;
    double? yInvertSize = yAxis.isInverted ? plotSize.height : null;
    return CartesianProjection(
      xTransform: PixelTransform.fromAxis(axis: xAxis, plotSize: plotSize.width, invertSize: xInvertSize),
      yTransform: PixelTransform.fromAxis(axis: yAxis, plotSize: plotSize.height, invertSize: yInvertSize),
    );
  }
}

class Polar2DProjection extends Projection<num> with Projection2D {
  const Polar2DProjection({
    required super.xTransform,
    required super.yTransform,
  });

  static Polar2DProjection fromAxes({
    required List<PlotAxis> axes,
    required Size plotSize,
  }) {
    assert(axes.length == 2, "PolarProjection requires two axes, got ${axes.length}");
    PlotAxis rAxis = axes[0];
    //PlotAxis thetaAxis = axes[1];
    double rMax = rAxis.bounds.max.toDouble();
    double x0 = -rMax;
    double y0 = -rMax;
    double xScale = plotSize.width / (2 * rMax);
    double yScale = plotSize.height / (2 * rMax);

    return Polar2DProjection(
      xTransform: PixelTransform(origin: x0, scale: xScale),
      yTransform: PixelTransform(origin: y0, scale: yScale),
    );
  }

  @override
  Offset map(List<num> coordinates) {
    assert(coordinates.length == 2, "Polar2DProjection requires two coordinates, got ${coordinates.length}");
    return Offset(
      // TODO: fix this, I think that the trig functions are backwards
      //coord1 * cos(coord2*degToRadians),
      //coord1 * sin(coord2*degToRadians),
      coordinates[0] * math.sin(coordinates[1] * degToRadians),
      coordinates[0] * math.cos(coordinates[1] * degToRadians),
    );
  }
}
