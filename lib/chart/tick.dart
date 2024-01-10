import "package:flutter/widgets.dart";

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
