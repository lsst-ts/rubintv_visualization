import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/focal_plane.dart';
import 'package:rubintv_visualization/state/workspace.dart';

class SelectDetectorAction extends UiAction {
  final Detector? detector;

  SelectDetectorAction(this.detector);
}

class Detector {
  final int id;
  final String name;
  final List<Offset> corners;
  final Rect bbox;

  Detector({
    required this.id,
    required this.name,
    required this.corners,
    required this.bbox,
  });

  static Detector fromCorners({
    required int id,
    required String name,
    required List<Offset> corners,
  }) {
    // Parse the corners, using the bottom-left as the origin
    double left = corners.map((corner) => corner.dx).reduce((a, b) => a < b ? a : b);
    double top = corners.map((corner) => corner.dy).reduce((a, b) => a < b ? a : b);
    double right = corners.map((corner) => corner.dx).reduce((a, b) => a > b ? a : b);
    double bottom = corners.map((corner) => corner.dy).reduce((a, b) => a > b ? a : b);
    return Detector(
      id: id,
      name: name,
      corners: corners,
      bbox: Rect.fromLTRB(left, top, right, bottom),
    );
  }
}

class DetectorPaintInfo {
  final Map<int, Path> detectorPaths;

  DetectorPaintInfo(this.detectorPaths);
}

typedef FocalPlanePainterCallback = void Function(DetectorPaintInfo info);

class FocalPlaneViewer extends StatefulWidget {
  final Instrument instrument;
  final Detector? selectedDetector;

  const FocalPlaneViewer({
    Key? key,
    required this.instrument,
    required this.selectedDetector,
  }) : super(key: key);

  @override
  FocalPlaneViewerState createState() => FocalPlaneViewerState();
}

class FocalPlaneViewerState extends State<FocalPlaneViewer> {
  DetectorPaintInfo? _detectorPaintInfo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (TapUpDetails details) {
        WorkspaceViewerState workspace = WorkspaceViewer.of(context);
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        Offset localPosition = renderBox.globalToLocal(details.globalPosition);
        // Check which detector was tapped
        for (Detector detector in widget.instrument.detectors) {
          if (_detectorPaintInfo != null &&
              _detectorPaintInfo!.detectorPaths[detector.id]!.contains(localPosition)) {
            // Handle tap on the detector
            workspace.dispatch(SelectDetectorAction(detector));
            return;
          }
        }
        workspace.dispatch(SelectDetectorAction(null));
      },
      child: CustomPaint(
        painter: FocalPlanePainter(
          widget.instrument.detectors,
          widget.selectedDetector,
          (info) {
            _detectorPaintInfo = info;
          },
        ),
      ),
    );
  }
}

class FocalPlanePainter extends CustomPainter {
  final List<Detector> detectors;
  final FocalPlanePainterCallback onPaintComplete;
  late final Rect focalPlaneRect;
  final Detector? selectedDetector;

  FocalPlanePainter(this.detectors, this.selectedDetector, this.onPaintComplete) {
    // Map the bounding box of the total focal plane at with the origin at the bottom-left
    double left = detectors.map((detector) => detector.bbox.left).reduce((a, b) => a < b ? a : b);
    double top = detectors.map((detector) => detector.bbox.top).reduce((a, b) => a < b ? a : b);
    double right = detectors.map((detector) => detector.bbox.right).reduce((a, b) => a > b ? a : b);
    double bottom = detectors.map((detector) => detector.bbox.bottom).reduce((a, b) => a > b ? a : b);
    focalPlaneRect = Rect.fromLTRB(left, top, right, bottom);
  }

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

  Path _drawDetector(Canvas canvas, Detector detector, Size size, Offset offset, double scale) {
    Paint paint = Paint()..color = selectedDetector?.id == detector.id ? Colors.red : Colors.blue;
    Path path = Path();
    List<Offset> corners = detector.corners
        .map((corner) => (Offset(corner.dx, size.height / scale - corner.dy) + offset) * scale)
        .toList();

    path.addPolygon(corners, true);
    canvas.drawPath(path, paint);
    return path;
  }

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
