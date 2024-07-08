import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:rubintv_visualization/focal_plane/color_picker.dart';

enum ColorbarOrientation { horizontal, vertical }

class ColorbarStop {
  final int id;
  double value;
  Color color;

  ColorbarStop({required this.id, required this.value, required this.color});

  @override
  String toString() {
    return 'ColorbarStop{id: $id, value: $value, color: $color}';
  }
}

class ColorbarState {
  final double min;
  final double max;
  final Map<int, ColorbarStop> stops;

  ColorbarState({
    required this.min,
    required this.max,
    required this.stops,
  });
}

typedef ColorbarStateCallback = void Function(ColorbarState state);

class ColorbarController {
  double _min;
  double _max;
  final Map<int, ColorbarStop> _stops;
  int _nextId = 0;
  List<ColorbarStateCallback> _observers = [];

  ColorbarController({
    required double min,
    required double max,
    required Map<double, Color> stops,
  })  : _stops = {},
        _min = min,
        _max = max {
    assert(stops.length >= 2, 'At least 2 stops are required');
    stops.forEach((key, value) {
      addStop(key, value);
    });
    if (_stops.length < 2) {
      throw Exception('At least 2 stops are required, got ${stops.keys}');
    }
  }

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

  void updateStop(int id, double newValue, Color newColor) {
    if (_stops.containsKey(id)) {
      ColorbarStop stop = _stops[id]!;
      stop.value = newValue.clamp(min, max);
      stop.color = newColor;
      notifyObservers();
    }
  }

  void removeStop(int id) {
    _stops.remove(id);
  }

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

  int get stopCount => _stops.length;

  LinkedHashMap<int, ColorbarStop> get stops {
    return LinkedHashMap.fromEntries(
        _stops.entries.toList()..sort((a, b) => a.value.value.compareTo(b.value.value)));
  }

  List<ColorbarStop> _getSortedStops() {
    return _stops.values.toList()..sort((a, b) => a.value.compareTo(b.value));
  }

  double get min => _min;
  double get max => _max;

  void subscribe(ColorbarStateCallback observer) {
    _observers.add(observer);
  }

  void unsubscribe(ColorbarStateCallback observer) {
    _observers.remove(observer);
  }

  void notifyObservers() {
    final state = ColorbarState(min: _min, max: _max, stops: _stops);
    for (ColorbarStateCallback observer in _observers) {
      observer(state);
    }
  }
}

class ColorbarSlider extends StatefulWidget {
  final ColorbarController controller;
  final ValueChanged<Map<int, ColorbarStop>>? onChanged;
  final ValueChanged<Map<int, ColorbarStop>>? onChangeStart;
  final ValueChanged<Map<int, ColorbarStop>>? onChangeEnd;
  final bool showLabels;
  final ColorbarOrientation orientation;
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

class ColorbarSliderState extends State<ColorbarSlider> {
  final double _handleSize = 20;
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

  Widget _buildHandle(ColorbarStop stop, Size size) {
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

  Offset _getPositionForValue(double value, Size size) {
    final percent = (value - widget.controller.min) / (widget.controller.max - widget.controller.min);
    final adjustedPercent = widget.flipMinMax ? 1 - percent : percent;

    return widget.orientation == ColorbarOrientation.horizontal
        ? Offset(size.width * adjustedPercent + _handleRadius, size.height / 2)
        : Offset(size.width / 2, size.height * (1 - adjustedPercent) + _handleRadius);
  }

  void _handlePanStart(ColorbarStop stop) {
    if (widget.onChangeStart != null) {
      widget.onChangeStart!(widget.controller.stops);
    }
  }

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

  void _handlePanEnd(ColorbarStop stop) {
    if (widget.onChangeEnd != null) {
      widget.onChangeEnd!(widget.controller.stops);
    }
  }
}

class ColorbarPainter extends CustomPainter {
  final ColorbarController controller;
  final bool showLabels;
  final ColorbarOrientation orientation;
  final bool flipMinMax;

  ColorbarPainter({
    required this.controller,
    required this.showLabels,
    required this.orientation,
    required this.flipMinMax,
  });

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

  void _drawLabel(Canvas canvas, Size size, double value) {
    final textSpan = TextSpan(
      text: value.toStringAsFixed(2),
      style: TextStyle(color: Colors.black, fontSize: 12),
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

  Offset _getPositionForValue(double value, Size size) {
    final percent = (value - controller.min) / (controller.max - controller.min);
    final adjustedPercent = flipMinMax ? 1 - percent : percent;

    return orientation == ColorbarOrientation.horizontal
        ? Offset(size.width * adjustedPercent, size.height / 2)
        : Offset(size.width / 2, size.height * (1 - adjustedPercent));
  }

  @override
  bool shouldRepaint(ColorbarPainter oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.orientation != orientation ||
        oldDelegate.flipMinMax != flipMinMax;
  }
}
