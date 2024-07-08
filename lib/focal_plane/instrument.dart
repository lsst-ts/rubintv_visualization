import 'package:flutter/material.dart';
import 'package:rubintv_visualization/workspace/state.dart';

class Instrument {
  final String name;
  final List<Detector> detectors;
  final String? schema;

  Instrument({
    required this.name,
    required this.detectors,
    this.schema,
  });

  static Instrument fromJson(Map<String, dynamic> json) {
    return Instrument(
      name: json["instrument"],
      detectors: (json["detectors"] as List).map(
        (detector) {
          return Detector.fromCorners(
            id: detector["id"],
            name: detector["name"],
            corners: (detector["corners"] as List).map((corner) {
              return Offset(corner[0], corner[1]);
            }).toList(),
          );
        },
      ).toList(),
      schema: json.containsKey("schema") ? json["schema"]["name"] : null,
    );
  }
}

class SelectDetectorEvent extends WorkspaceEvent {
  final Detector? detector;

  SelectDetectorEvent(this.detector);
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
