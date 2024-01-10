import 'dart:math' as math;
import 'package:rubintv_visualization/utils.dart';

/// The orientation of a plot axis
enum AxisOrientation {
  vertical,
  horizontal,
  radial,
  angular,
}

/// Major or minor ticks for a [PlotAxis].
class AxisTicks {
  /// Factor that all of the ticks are multiples of.
  final double tickFactor;

  /// The ticks on the axis.
  final List<double> ticks;

  /// The label for each tick (optional for a minor axis).
  final List<String>? labels;

  const AxisTicks({
    required this.tickFactor,
    required this.ticks,
    this.labels,
  });

  /// The bounds of the tick marks
  Bounds get bounds => Bounds(ticks.first, ticks.last);
}

/// This algorithm is from Graphics Gems, by Andrew Glassner,
/// in the chapter "Nice Numbers for Graph Labels" to generate numbers
/// that are a factor of 1, 2, 5, or 10, hence the term "Nice Numbers."
/// TODO: implement a better algorithm.
double getNiceNumber(double x, bool round) {
  double logX = math.log(x) / math.ln10;
  int power = logX.floor();

  double nearest10 = math.pow(10, power).toDouble();
  // The factor will be between ~1 and ~10 (with some rounding errors)
  double factor = x / nearest10;

  if (round) {
    if (factor < 1.5) {
      factor = 1;
    } else if (factor < 3) {
      factor = 2;
    } else if (factor < 7) {
      factor = 5;
    } else {
      factor = 10;
    }
  } else {
    if (factor <= 1) {
      factor = 1;
    } else if (factor <= 2) {
      factor = 2;
    } else if (factor <= 5) {
      factor = 5;
    } else {
      factor = 10;
    }
  }
  return factor * nearest10;
}

/// This algorithm is from Graphics Gems, by Andrew Glassner,
/// in the chapter "Nice Numbers for Graph Labels" to make an
/// axis range from a minimum value to a maximum value in numbers
/// that are a factor of 1, 2, 5, or 10.
AxisTicks getMajorTicks({
  required double min,
  required double max,
  required int nTicks,
}) {
  double range = getNiceNumber(max - min, false);
  double tick = getNiceNumber(range / (nTicks - 1), true);
  double minTick = (min / tick).floor() * tick;

  List<double> majorTicks = List.generate(nTicks, (t) => minTick + t * tick);
  if (majorTicks.last < max) {
    majorTicks.add(min + tick * nTicks);
  }
  List<String> labels = tickToString(ticks: majorTicks, tickFactor: tick);

  return AxisTicks(
    tickFactor: tick,
    ticks: majorTicks,
    labels: labels,
  );
}

/// The significant figures in a number
int getSigFig(num x) {
  String xStr = x.toString();
  List<String> split = xStr.split(".");

  if (split.length == 1 || split[1] == "0") {
    return trimStringRight(split[0], "0").length;
  }
  int leftSig = split[0] == "0" ? 0 : split[0].length;
  if (leftSig == 0) {
    return trimStringLeft(split[1], "0").length + leftSig;
  }
  return split[1].length + leftSig;
}

List<String> tickToString({
  required List<double> ticks,
  required double? tickFactor,
  int? precision,
}) {
  List<String> labels = [];
  if (tickFactor != null && tickFactor == tickFactor.toInt()) {
    for (double x in ticks) {
      labels.add(x.toInt().toString());
    }
  } else {
    if (precision == null) {
      if (tickFactor == null) {
        throw ArgumentError("Must either specify `tickFactor` or `precision`, got `null` for both.");
      }
      precision = getSigFig(tickFactor);
    }

    for (double x in ticks) {
      labels.add(x.toStringAsPrecision(precision));
    }
  }

  return labels;
}

/// Parameters needed to define an axis.
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
