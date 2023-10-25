import 'package:rubintv_visualization/utils.dart';

/// The orientation of a plot axis
enum AxisOrientation {
  vertical,
  horizontal,
  radial,
  angular,
}

class PlotAxis {
  /// The orientation of the axis.
  final AxisOrientation orientation;

  /// Label of the axis in a plot.
  final String label;

  /// The max/min bounds of the axis displayed in a plot.
  final Bounds? bounds;

  /// Whether or not the bounds are fixed.
  final bool boundsFixed;

  /// True if the displayed axis is inverted
  final bool isInverted;

  const PlotAxis({
    required this.label,
    required this.bounds,
    required this.orientation,
    this.boundsFixed = false,
    this.isInverted = false,
  });

  PlotAxis copyWith({
    String? label,
    Bounds? bounds,
    AxisOrientation? orientation,
    bool? boundsFixed,
    bool? isInverted,
  }) =>
      PlotAxis(
        label: label ?? this.label,
        bounds: bounds ?? this.bounds,
        orientation: orientation ?? this.orientation,
        boundsFixed: boundsFixed ?? this.boundsFixed,
        isInverted: isInverted ?? this.isInverted,
      );

  /// Make a copy of this [PlotAxis].
  PlotAxis copy() => copyWith();
}
