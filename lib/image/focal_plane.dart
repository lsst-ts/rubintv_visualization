import 'package:flutter/material.dart';

class Detector {
  final int id;
  final String name;
  final List<Offset> corners;

  Detector({
    required this.id,
    required this.name,
    required this.corners,
  });
}

class FocalPlane extends StatefulWidget {
  final List<Detector> detectors;

  const FocalPlane({Key? key, required this.detectors}) : super(key: key);

  @override
  FocalPlaneState createState() => FocalPlaneState();
}

class FocalPlaneState extends State<FocalPlane> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (TapUpDetails details) {
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        Offset localPosition = renderBox.globalToLocal(details.globalPosition);
        // Check which detector was tapped
        for (Detector detector in widget.detectors) {
          if (_createPath(detector).contains(localPosition)) {
            // Handle tap on the detector
            print("Tapped on detector ${detector.id}");
            break;
          }
        }
      },
      child: CustomPaint(
        painter: FocalPlanePainter(widget.detectors),
        size: Size.infinite, // or some other appropriate size
      ),
    );
  }

  Path _createPath(Detector detector) {
    Path path = Path();
    path.addPolygon(detector.corners, true);
    return path;
  }
}

class FocalPlanePainter extends CustomPainter {
  final List<Detector> detectors;

  FocalPlanePainter(this.detectors);

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = Colors.blue;
    for (Detector detector in detectors) {
      Path path = Path();
      path.addPolygon(detector.corners, true);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // You could improve this by only repainting if data changes
  }
}

void main() {
  runApp(MaterialApp(
      home: FocalPlane(detectors: [
    Detector(
        id: 1,
        name: "Detector 1",
        corners: [Offset(100, 100), Offset(200, 100), Offset(200, 200), Offset(100, 200)]),
    // Add more detectors
  ])));
}
