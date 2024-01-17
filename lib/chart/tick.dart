import "dart:math";
import "package:flutter/widgets.dart";
import "package:rubintv_visualization/utils.dart";

/// The location on the tick label where it attaches to the plot.
/// For cartesian plots, ticks on the x-axis attach to [TickPosition.topCenter]
///
enum TickPosition {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

/// A tick on an axis.
class TickLabel {
  /// The text of the tick label.
  final String text;

  /// The location on the tick label where it attaches to the plot.
  final TickPosition position;

  /// The style of the tick label.
  final TextStyle style;

  /// The rotation of the tick label in radians relative to the x-axis.
  final double rotation;

  const TickLabel({
    required this.text,
    required this.position,
    required this.style,
    required this.rotation,
  });
}

/// A widget that displays a [TickLabel].
class TickLabelWidget extends StatelessWidget {
  /// The tick label to display.
  final TickLabel tickLabel;

  const TickLabelWidget({super.key, required this.tickLabel});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tickLabel.rotation,
      child: Text(
        tickLabel.text,
        style: tickLabel.style,
      ),
    );
  }
}

/// A class for calculating nice numbers for ticks
class NiceNumber {
  // The power of 10 (ie. 10^power gives the [nearest10] value)
  final int power;
  // The factor of the [nearest10] value (ie. [factor] * [nearest10] gives the [value])
  final double factor;
  // The nearest 10th value (ie. [nearest10] * 10^power gives the [value])
  final double nearest10;

  NiceNumber(this.power, this.factor, this.nearest10);

  // The "nice" factors. All ticks will be one of the [factors] * a power of 10.
  static List<double> factors = [1, 2, 5, 10];
  // The number of possible factors.
  int get nFactors => factors.length;

  // Instantiate a [NiceNumber] from a double.
  static fromDouble(double x, bool round) {
    double logX = log(x) / ln10;
    int power = logX.floor();

    double nearest10 = power >= 0 ? pow(10, power).toDouble() : 1 / pow(10, -power).toDouble();
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
    return NiceNumber(power, factor, nearest10);
  }

  // The value of the [NiceNumber].
  double get value => factor * nearest10;

  // Modify the factor by [index] (ie. [index] = 1 will increase the factor by 1).
  // If the factor is modified to be outside of the [factors] list,
  // the [power] and [nearest10] will be modified accordingly.
  NiceNumber modifyFactor(int index) {
    if (index == 0) {
      return this;
    }

    int factorIndex = factors.indexOf(factor) + index;
    int newIndex = factorIndex % nFactors;
    int newPower = power + factorIndex ~/ nFactors;
    if (factorIndex < 0) {
      newPower -= 1;
    }

    double nearest10 = newPower >= 0 ? pow(10, newPower).toDouble() : 1 / pow(10, -newPower).toDouble();
    double newFactor = factors[newIndex];
    return NiceNumber(newPower, newFactor, nearest10);
  }

  @override
  String toString() => "$value: power=$power, factor=$factor, nearest10th=$nearest10";
}

/// Calculate the step size to generate ticks in [range].
/// If [encloseBounds] is true then ticks will be added to the
/// each side so that the bounds are included in the ticks
/// (usually used for initialization).
/// Otherwise the ticks will be inside or equal to the bounds.
NiceNumber calculateStepSize(
  int nTicks,
  NiceNumber stepSize,
  double range,
  bool encloseBounds,
  int extrema,
  ComparisonOperators operator,
) {
  int iterations = 0;
  NiceNumber initialStepSize = stepSize;
  while (compare<num>(nTicks, extrema, operator)) {
    stepSize = stepSize.modifyFactor(-1);
    nTicks = (range / stepSize.value).ceil() + 1;
    if (encloseBounds) {
      nTicks += 2;
    }
    if (iterations++ > 5) {
      // Just use the original value
      print("Warning: Could not find a nice number for the ticks");
      return initialStepSize;
    }
  }
  return stepSize;
}

/// A class for calculating ticks for an axis.
class Ticks {
  /// The step size between ticks
  final NiceNumber stepSize;

  /// The ticks
  final List<double> ticks;

  /// The minimum value of the axis.
  final double min;

  /// The maximum value of the axis.
  final double max;

  Ticks(this.stepSize, this.ticks, this.min, this.max);

  /// Generate tick marks for a range of numbers.
  /// If [encloseBounds] is true then ticks will be added to the
  /// each side so that the bounds are included in the ticks
  /// (usually used for initialization).
  /// Otherwise the ticks will be inside or equal to the bounds.
  static Ticks fromRange(double min, double max, int minTicks, int maxTicks, bool encloseBounds) {
    assert(max > min, "max must be greater than min");

    // Pick the mean number of ticks to test out initially.
    int avgTicks = (minTicks + maxTicks) ~/ 2;
    NiceNumber stepSize = NiceNumber.fromDouble((max - min) / (avgTicks - 1), true);

    // If number of ticks is outside of the desired tick range,
    // then modify the step size until it is within the range.
    double range = max - min;
    int nTicks = (range / stepSize.value).ceil() + 1;
    if (encloseBounds) {
      nTicks += 2;
    }
    if (nTicks < minTicks) {
      stepSize = calculateStepSize(nTicks, stepSize, range, encloseBounds, minTicks, ComparisonOperators.lt);
    } else if (nTicks > maxTicks) {
      stepSize = calculateStepSize(nTicks, stepSize, range, encloseBounds, maxTicks, ComparisonOperators.gt);
    }

    // Set the ticks based on the step size and whether or not the axis bounds should be included.
    double step = stepSize.value;
    List<double> ticks = [];
    if (encloseBounds) {
      // Make the ticks outside of the bounds
      min = (min / step).floor() * step;
      max = (max / step).ceil() * step;
      for (double val = min; val <= max + step; val += step) {
        ticks.add(val);
      }
    } else {
      // Make the ticks inside the bounds
      min = (min / step).ceil() * step;
      max = (max / step).floor() * step;
      for (double val = min; val < max + step; val += step) {
        ticks.add(val);
      }
    }

    return Ticks(stepSize, ticks, min, max);
  }

  /// The number of ticks.
  int get length => ticks.length;

  @override
  String toString() => "[${ticks.map((e) => e.toStringAsFixed(stepSize.power.abs()))}]";

  /// Get the [index]th tick as a string with the correct number of decimal places.
  String tick(int index) => ticks[index].toStringAsFixed(stepSize.power.abs());
}
