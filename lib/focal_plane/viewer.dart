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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/focal_plane/instrument.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// Information about the paths of the detectors on the focal plane.
class DetectorPaintInfo {
  /// The paths of the detectors on the focal plane.
  final Map<int, Path> detectorPaths;

  DetectorPaintInfo(this.detectorPaths);
}

/// A callback function that is called when the painting of the focal plane is complete.
typedef FocalPlanePainterCallback = void Function(DetectorPaintInfo info);

/// A [StatefulWidget] that displays the focal plane of an instrument.
class FocalPlaneViewer extends StatefulWidget {
  /// The window that contains the viewer.
  final WindowMetaData window;

  /// The instrument to display.
  final Instrument instrument;

  /// The selected detector.
  final Detector? selectedDetector;

  /// The workspace state.
  final WorkspaceState workspace;

  /// The colors of the detectors.
  /// If not specified, the detectors will be blue, and the selected detector will be red.
  final Map<int, Color>? detectorColors;

  const FocalPlaneViewer({
    super.key,
    required this.window,
    required this.instrument,
    required this.selectedDetector,
    required this.workspace,
    this.detectorColors,
  });

  @override
  FocalPlaneViewerState createState() => FocalPlaneViewerState();
}

/// The state of the [FocalPlaneViewer].
class FocalPlaneViewerState extends State<FocalPlaneViewer> {
  /// The information about the detectors on the focal plane.
  DetectorPaintInfo? _detectorPaintInfo;
  Detector? _currentSelectedDetector;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentSelectedDetector = widget.selectedDetector;
    _focusNode.requestFocus(); // Automatically focus on this widget
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent) {
          return _handleKeyEvent(event);
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTapUp: (TapUpDetails details) => _handleTap(details, context),
        child: SizedBox.expand(
          child: CustomPaint(
            painter: FocalPlanePainter(
              widget.instrument.detectors,
              widget.selectedDetector,
              (info) {
                _detectorPaintInfo = info;
              },
              widget.detectorColors,
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(KeyDownEvent event) {
    if (_detectorPaintInfo == null) return KeyEventResult.ignored;

    // Navigation logic based on arrow keys
    Detector? nextDetector;
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      nextDetector = _findNearestDetector(const Offset(0, -1));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      nextDetector = _findNearestDetector(const Offset(0, 1));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      nextDetector = _findNearestDetector(const Offset(-1, 0));
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      nextDetector = _findNearestDetector(const Offset(1, 0));
    }

    if (nextDetector != null) {
      _currentSelectedDetector = nextDetector;
      context.read<WorkspaceBloc>().add(SelectDetectorEvent(nextDetector));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Detector? _findNearestDetector(Offset direction) {
    if (_currentSelectedDetector == null || _detectorPaintInfo == null) return null;

    final Path? currentPath = _detectorPaintInfo!.detectorPaths[_currentSelectedDetector!.id];
    if (currentPath == null) {
      return null;
    }

    Offset currentCenter = currentPath.getBounds().center;

    Detector? bestDetector;
    double bestDistance = double.infinity;

    for (final detector in widget.instrument.detectors) {
      if (detector.id == _currentSelectedDetector!.id) continue;

      final Path? path = _detectorPaintInfo!.detectorPaths[detector.id];
      if (path == null) continue;

      Offset center = path.getBounds().center;
      Offset diff = center - currentCenter;

      if (direction.dx > 0 && diff.dx <= 0) continue; // Ignore detectors to the left
      if (direction.dx < 0 && diff.dx >= 0) continue; // Ignore detectors to the right
      if (direction.dy > 0 && diff.dy <= 0) continue; // Ignore detectors below
      if (direction.dy < 0 && diff.dy >= 0) continue; // Ignore detectors above

      // Distance calculation
      double distance = diff.distanceSquared;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestDetector = detector;
      }
    }

    return bestDetector;
  }

  void _handleTap(TapUpDetails details, BuildContext context) {
    RenderBox renderBox = context.findRenderObject() as RenderBox;
    Offset localPosition = renderBox.globalToLocal(details.globalPosition);

    for (Detector detector in widget.instrument.detectors) {
      if (_detectorPaintInfo != null &&
          _detectorPaintInfo!.detectorPaths[detector.id]!.contains(localPosition)) {
        context.read<WorkspaceBloc>().add(SelectDetectorEvent(detector));
        _currentSelectedDetector = detector;
        return;
      }
    }
    context.read<WorkspaceBloc>().add(SelectDetectorEvent(null));
    _currentSelectedDetector = null;
  }
}

/// A [CustomPainter] that paints the focal plane of an instrument.
class FocalPlanePainter extends CustomPainter {
  /// The detectors on the focal plane.
  final List<Detector> detectors;

  /// Callback for when the painting is complete.
  final FocalPlanePainterCallback onPaintComplete;

  /// The bounding box of the focal plane.
  late final Rect focalPlaneRect;

  /// The selected detector.
  final Detector? selectedDetector;

  /// The colors of the detectors.
  final Map<int, Color>? detectorColors;

  FocalPlanePainter(this.detectors, this.selectedDetector, this.onPaintComplete, this.detectorColors) {
    // Map the bounding box of the total focal plane at with the origin at the bottom-left
    double left = detectors.map((detector) => detector.bbox.left).reduce((a, b) => a < b ? a : b);
    double top = detectors.map((detector) => detector.bbox.top).reduce((a, b) => a < b ? a : b);
    double right = detectors.map((detector) => detector.bbox.right).reduce((a, b) => a > b ? a : b);
    double bottom = detectors.map((detector) => detector.bbox.bottom).reduce((a, b) => a > b ? a : b);
    focalPlaneRect = Rect.fromLTRB(left, top, right, bottom);
  }

  /// Paint the detectors on the focal plane.
  @override
  void paint(Canvas canvas, Size size) {
    double scale = math.min(size.width / focalPlaneRect.width, size.height / focalPlaneRect.height);
    Offset offset = Offset(-focalPlaneRect.left, focalPlaneRect.top);

    offset += Offset(
      (size.width / scale - focalPlaneRect.width) / 2,
      (-size.height / scale + focalPlaneRect.height) / 2,
    );

    Map<int, Path> detectorPaths = {};
    for (Detector detector in detectors) {
      detectorPaths[detector.id] = _drawDetector(canvas, detector, size, offset, scale);
      _drawDetectorInfo(canvas, detector, size, offset, scale);
    }

    onPaintComplete(DetectorPaintInfo(detectorPaths));
  }

  /// Draw a detector on the focal plane.
  Path _drawDetector(Canvas canvas, Detector detector, Size size, Offset offset, double scale) {
    Color detectorColor = selectedDetector?.id == detector.id ? Colors.red : Colors.blue;
    if (detectorColors != null) {
      detectorColor = detectorColors![detector.id] ?? detectorColor;
    }
    Paint paint = Paint()..color = detectorColor;
    Path path = Path();
    List<Offset> corners = detector.corners
        .map((corner) => (Offset(corner.dx, size.height / scale - corner.dy) + offset) * scale)
        .toList();

    path.addPolygon(corners, true);
    canvas.drawPath(path, paint);
    return path;
  }

  /// Draw the information about a detector on the focal plane.
  void _drawDetectorInfo(Canvas canvas, Detector detector, Size size, Offset offset, double scale) {
    TextPainter textPainter = TextPainter(
      maxLines: 2,
      textAlign: TextAlign.center,
      text: TextSpan(
        text: "${detector.id}",
        style: const TextStyle(color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    Offset center =
        (Offset(detector.bbox.center.dx, size.height / scale - detector.bbox.center.dy) + offset) * scale -
            Offset(
              textPainter.width / 2,
              textPainter.height / 2,
            );
    textPainter.paint(canvas, center);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // You could improve this by only repainting if data changes
  }
}
