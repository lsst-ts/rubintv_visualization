import 'package:flutter/material.dart';

enum CartesianLayoutElement {
  title,
  legend,
  xAxisBottom,
  xAxisTop,
  yAxisLeft,
  yAxisRight,
  plot,
}

class CartesianPlotLayoutDelegate extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    final BoxConstraints constraints = BoxConstraints.loose(size);

    // Step 1: Layout the rotated vertical axis label.
    final Size sizeY1 =
        layoutChild(CartesianLayoutElement.yAxisLeft, constraints);
    // Step 2: Layout A (the horizontal axis label)
    final Size sizeX1 =
        layoutChild(CartesianLayoutElement.xAxisBottom, constraints);
    // Step 3: Layout C (the main plot widget) with the remaining space
    final double plotWidth = size.width - sizeY1.width;
    final double plotHeight = size.height - sizeX1.height;
    layoutChild(CartesianLayoutElement.plot,
        constraints.copyWith(maxWidth: plotWidth, maxHeight: plotHeight));

    // Step 4: position the elements
    Offset y1Offset = Offset(0, (plotHeight - sizeY1.height) / 2);
    Offset plotOffset = Offset(sizeY1.width, 0);
    Offset x1Offset = Offset(sizeY1.width + (plotWidth - sizeX1.width) / 2,
        size.height - sizeX1.height);
    positionChild(CartesianLayoutElement.yAxisLeft, y1Offset);
    positionChild(CartesianLayoutElement.xAxisBottom, x1Offset);
    positionChild(CartesianLayoutElement.plot, plotOffset);
  }

  @override
  bool shouldRelayout(covariant MultiChildLayoutDelegate oldDelegate) => false;
}
