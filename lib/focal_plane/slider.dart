/// This file is part of the rubintv_visualization package.
///
/// Developed for the LSST Data Management System.
/// This product includes software developed by the LSST Project
/// (https://www.lsst.org).
/// See the COPYRIGHT file at the top-level directory of this distribution
/// for details of code ownership.
///
/// This program is free software: you can redistribute it and/or modify
/// it under the terms of the GNU General Public License as published by
/// the Free Software Foundation, either version 3 of the License, or
/// (at your option) any later version.
///
/// This program is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
/// GNU General Public License for more details.
///
/// You should have received a copy of the GNU General Public License
/// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:rubintv_visualization/focal_plane/color_picker.dart';

/// The orientation of the colorbar.
enum ColorbarOrientation { horizontal, vertical }

/// A stop on the colorbar.
class ColorbarStop {
  /// The unique identifier of the stop.
  final int id;

  /// The value of the stop.
  double value;

  /// The color of the stop.
  Color color;

  ColorbarStop({required this.id, required this.value, required this.color});

  @override
  String toString() {
    return 'ColorbarStop{id: $id, value: $value, color: $color}';
  }
}

/// The state of the colorbar.
class ColorbarState {
  /// The minimum value of the colorbar.
  final double min;

  /// The maximum value of the colorbar.
  final double max;

  /// The stops on the colorbar.
  final Map<int, ColorbarStop> stops;

  ColorbarState({
    required this.min,
    required this.max,
    required this.stops,
  });
}

/// A callback function that is called when the state of the colorbar changes.
typedef ColorbarStateCallback = void Function(ColorbarState state);

/// A controller for the colorbar.
class ColorbarController {
  /// The minimum value of the colorbar.
  double _min;

  /// The maximum value of the colorbar.
  double _max;

  /// The stops on the colorbar.
  final Map<int, ColorbarStop> _stops;

  /// The next unique identifier for a stop.
  int _nextId = 0;

  /// The observers of the colorbar.
  final List<ColorbarStateCallback> _observers = [];

  ColorbarController({
    required double min,
    required double max,
    required Map<double, Color> stops,
  })  : _stops = {},
        _min = min,
        _max = max {
    assert(stops.length >= 2, 'At least 2 stops are required');
    // Add stops in order
    stops.forEach((key, value) {
      addStop(key, value);
    });
    if (_stops.length < 2) {
      throw Exception('At least 2 stops are required, got ${stops.keys}');
    }
  }

  /// Get the color for a given value.
  Color getColor(double value) {
    List<ColorbarStop> sortedStops = _getSortedStops();
    if (value <= sortedStops.first.value) return sortedStops.first.color;
    if (value >= sortedStops.last.value) return sortedStops.last.color;

    for (int i = 0; i < sortedStops.length - 1; i++) {
      final ColorbarStop currentStop = sortedStops[i];
      final ColorbarStop nextStop = sortedStops[i + 1];
      if (value >= currentStop.value && value <= nextStop.value) {
        double t = (value - currentStop.value) / (nextStop.value - currentStop.value);
        return Color.lerp(currentStop.color, nextStop.color, t)!;
      }
    }

    return sortedStops.last.color;
  }

  /// Add a stop to the colorbar.
  int addStop(double value, Color color) {
    if (value < min) {
      value = min;
    }
    if (value > max) {
      value = max;
    }
    int id = _nextId++;
    _stops[id] = ColorbarStop(id: id, value: value, color: color);
    notifyObservers();
    return id;
  }

  /// Update a stop on the colorbar.
  void updateStop(int id, double newValue, Color newColor) {
    if (_stops.containsKey(id)) {
      ColorbarStop stop = _stops[id]!;
      stop.value = newValue.clamp(min, max);
      stop.color = newColor;
      notifyObservers();
    }
  }

  /// Remove a stop from the colorbar.
  void removeStop(int id) {
    _stops.remove(id);
  }

  /// Update the bounds of the colorbar.
  void updateBounds({required double min, required double max, bool adjustStops = true}) {
    if (adjustStops) {
      double oldRange = _max - _min;
      double newRange = max - min;

      for (ColorbarStop stop in _stops.values) {
        stop.value = min + (stop.value - _min) / oldRange * newRange;
      }
    }

    _min = min;
    _max = max;
    notifyObservers();
  }

  /// Get the number of stops on the colorbar.
  int get stopCount => _stops.length;

  /// Get the stops on the colorbar.
  LinkedHashMap<int, ColorbarStop> get stops {
    return LinkedHashMap.fromEntries(
        _stops.entries.toList()..sort((a, b) => a.value.value.compareTo(b.value.value)));
  }

  /// Get the stops on the colorbar sorted by value.
  List<ColorbarStop> _getSortedStops() {
    return _stops.values.toList()..sort((a, b) => a.value.compareTo(b.value));
  }

  /// Get the minimum and maximum values of the colorbar.
  double get min => _min;

  /// Get the minimum and maximum values of the colorbar.
  double get max => _max;

  /// Subscribe to changes in the colorbar.
  void subscribe(ColorbarStateCallback observer) {
    _observers.add(observer);
  }

  /// Unsubscribe from changes in the colorbar.
  void unsubscribe(ColorbarStateCallback observer) {
    _observers.remove(observer);
  }

  /// Notify observers of changes in the colorbar.
  void notifyObservers() {
    final state = ColorbarState(min: _min, max: _max, stops: _stops);
    for (ColorbarStateCallback observer in _observers) {
      observer(state);
    }
  }
}

/// A slider for selecting colors on a colorbar.
class ColorbarSlider extends StatefulWidget {
  /// The controller for the colorbar.
  final ColorbarController controller;

  /// Callback for when the colorbar changes.
  final ValueChanged<Map<int, ColorbarStop>>? onChanged;

  /// Callback for when the colorbar change starts.
  final ValueChanged<Map<int, ColorbarStop>>? onChangeStart;

  /// Callback for when the colorbar change ends.
  final ValueChanged<Map<int, ColorbarStop>>? onChangeEnd;

  /// Whether to show labels on the colorbar.
  final bool showLabels;

  /// The orientation of the colorbar.
  final ColorbarOrientation orientation;

  /// Whether to flip the minimum and maximum values of the colorbar.
  final bool flipMinMax;

  const ColorbarSlider({
    super.key,
    required this.controller,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.showLabels = false,
    this.orientation = ColorbarOrientation.horizontal,
    this.flipMinMax = false,
  });

  @override
  ColorbarSliderState createState() => ColorbarSliderState();
}

/// The state of the colorbar slider.
class ColorbarSliderState extends State<ColorbarSlider> {
  /// The size of the stop handles.
  final double _handleSize = 20;

  /// The radius of the stop handles.
  double get _handleRadius => _handleSize / 2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final Size fullSize = Size(constraints.maxWidth, constraints.maxHeight);
        final Size size = widget.orientation == ColorbarOrientation.horizontal
            ? Size(constraints.maxWidth - _handleSize, constraints.maxHeight)
            : Size(constraints.maxWidth, constraints.maxHeight - _handleSize);

        return GestureDetector(
          onTapUp: (TapUpDetails details) {
            RenderBox renderBox = context.findRenderObject() as RenderBox;
            Offset localPosition = renderBox.globalToLocal(details.globalPosition);
            final double percent = widget.orientation == ColorbarOrientation.horizontal
                ? localPosition.dx / fullSize.width
                : 1 - (localPosition.dy / fullSize.height);
            final double adjustedPercent = widget.flipMinMax ? 1 - percent : percent;
            final double newValue =
                widget.controller.min + (widget.controller.max - widget.controller.min) * adjustedPercent;
            final Color newColor = widget.controller.getColor(newValue);
            widget.controller.addStop(newValue, newColor);

            if (widget.onChanged != null) {
              widget.onChanged!(widget.controller.stops);
            }
            setState(() {});
          },
          child: SizedBox(
            width: fullSize.width,
            height: fullSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: widget.orientation == ColorbarOrientation.horizontal ? _handleRadius : 0,
                  top: widget.orientation == ColorbarOrientation.vertical ? _handleRadius : 0,
                  child: CustomPaint(
                    size: size,
                    painter: ColorbarPainter(
                      controller: widget.controller,
                      showLabels: widget.showLabels,
                      orientation: widget.orientation,
                      flipMinMax: widget.flipMinMax,
                    ),
                  ),
                ),
                ...widget.controller.stops.entries.map((stop) {
                  return _buildHandle(stop.value, size);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build a handle for a stop on the colorbar.
  Widget _buildHandle(ColorbarStop stop, Size size) {
    /// The position of the handle.
    final Offset position = _getPositionForValue(stop.value, size);

    return Positioned(
      left: position.dx - _handleRadius,
      top: position.dy - _handleRadius,
      child: GestureDetector(
        onPanStart: (_) => _handlePanStart(stop),
        onPanUpdate: (details) => _handlePanUpdate(stop, details, size),
        onPanEnd: (_) => _handlePanEnd(stop),
        onTapUp: (TapUpDetails details) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return ColorPickerDialog(
                initialStop: stop,
                controller: widget.controller,
              );
            },
          ).then((result) {
            setState(() {});
          });
        },
        child: Container(
          width: _handleSize,
          height: _handleSize,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: _handleSize * 2 / 3,
              height: _handleSize * 2 / 3,
              decoration: BoxDecoration(
                color: stop.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Get the position of a handle for a given value.
  Offset _getPositionForValue(double value, Size size) {
    final percent = (value - widget.controller.min) / (widget.controller.max - widget.controller.min);
    final adjustedPercent = widget.flipMinMax ? 1 - percent : percent;

    return widget.orientation == ColorbarOrientation.horizontal
        ? Offset(size.width * adjustedPercent + _handleRadius, size.height / 2)
        : Offset(size.width / 2, size.height * (1 - adjustedPercent) + _handleRadius);
  }

  /// Call the onChangeState callback when a pan gesture on a handle starts.
  void _handlePanStart(ColorbarStop stop) {
    if (widget.onChangeStart != null) {
      widget.onChangeStart!(widget.controller.stops);
    }
  }

  /// Update the colorbar when a pan gesture on a handle updates.
  void _handlePanUpdate(ColorbarStop stop, DragUpdateDetails details, Size size) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final position = renderBox.globalToLocal(details.globalPosition);
    final percent = widget.orientation == ColorbarOrientation.horizontal
        ? position.dx / size.width
        : 1 - (position.dy / size.height);
    final adjustedPercent = widget.flipMinMax ? 1 - percent : percent;
    final newValue =
        widget.controller.min + (widget.controller.max - widget.controller.min) * adjustedPercent;

    setState(() {
      widget.controller.updateStop(stop.id, newValue, widget.controller._stops[stop.id]!.color);
    });

    if (widget.onChanged != null) {
      widget.onChanged!(widget.controller.stops);
    }
  }

  /// Update the colorbar when a pan gesture on a handle ends.
  void _handlePanEnd(ColorbarStop stop) {
    if (widget.onChangeEnd != null) {
      widget.onChangeEnd!(widget.controller.stops);
    }
  }
}

/// Draw the colorbar on a [Canvas].
class ColorbarPainter extends CustomPainter {
  /// The controller for the colorbar.
  final ColorbarController controller;

  /// Whether to show labels on the colorbar.
  final bool showLabels;

  /// The orientation of the colorbar.
  final ColorbarOrientation orientation;

  /// Whether to flip the minimum and maximum values of the colorbar.
  final bool flipMinMax;

  ColorbarPainter({
    required this.controller,
    required this.showLabels,
    required this.orientation,
    required this.flipMinMax,
  });

  /// Paint the colorbar on the canvas.
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final rect = Offset.zero & size;

    // Draw gradient
    final gradient = LinearGradient(
      colors: controller.stops.entries.map((s) => s.value.color).toList(),
      stops: controller.stops.entries
          .map((s) => (s.value.value - controller.min) / (controller.max - controller.min))
          .toList(),
      begin: orientation == ColorbarOrientation.horizontal
          ? (flipMinMax ? Alignment.centerRight : Alignment.centerLeft)
          : (flipMinMax ? Alignment.topCenter : Alignment.bottomCenter),
      end: orientation == ColorbarOrientation.horizontal
          ? (flipMinMax ? Alignment.centerLeft : Alignment.centerRight)
          : (flipMinMax ? Alignment.bottomCenter : Alignment.topCenter),
    );

    paint.shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // Draw handles and labels
    for (ColorbarStop stop in controller.stops.values) {
      if (showLabels) {
        _drawLabel(canvas, size, stop.value);
      }
    }
  }

  /// Draw a label for the stop.
  void _drawLabel(Canvas canvas, Size size, double value) {
    final textSpan = TextSpan(
      text: value.toStringAsFixed(2),
      style: const TextStyle(color: Colors.black, fontSize: 12),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final position = _getPositionForValue(value, size);
    final offset = orientation == ColorbarOrientation.horizontal
        ? Offset(position.dx - textPainter.width / 2, size.height + 5)
        : Offset(size.width + 5, position.dy - textPainter.height / 2);

    textPainter.paint(canvas, offset);
  }

  /// Get the position of a handle for a given value.
  Offset _getPositionForValue(double value, Size size) {
    final percent = (value - controller.min) / (controller.max - controller.min);
    final adjustedPercent = flipMinMax ? 1 - percent : percent;

    return orientation == ColorbarOrientation.horizontal
        ? Offset(size.width * adjustedPercent, size.height / 2)
        : Offset(size.width / 2, size.height * (1 - adjustedPercent));
  }

  /// Determine if the colorbar needs to be repainted.
  @override
  bool shouldRepaint(ColorbarPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.orientation != orientation ||
        oldDelegate.flipMinMax != flipMinMax;
  }
}
