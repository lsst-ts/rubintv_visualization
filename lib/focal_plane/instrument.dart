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

import 'package:flutter/material.dart';
import 'package:rubintv_visualization/workspace/state.dart';

/// An instrument (camera) defined in obs_lsst.
class Instrument {
  /// The name of the instrument
  final String name;

  /// The detectors in the instrument
  final List<Detector> detectors;

  /// The name of the schema associated with the instrument
  final String? schema;

  Instrument({
    required this.name,
    required this.detectors,
    this.schema,
  });

  /// Convert the [Instrument] to a JSON object.
  Map<String, dynamic> toJson() {
    Map<String, dynamic> result = {
      "instrument": name,
      "detectors": detectors.map((detector) => detector.toJson()).toList(),
    };
    if (schema != null) {
      result["schema"] = {"name": schema};
    }
    return result;
  }

  /// Parse the instrument from a JSON object
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

/// An event used to select a detector in the focal plane.
class SelectDetectorEvent extends WorkspaceEvent {
  /// The detector to select
  final Detector? detector;

  SelectDetectorEvent(this.detector);
}

/// A detector in the focal plane of a camera.
class Detector {
  /// The number of the detector.
  final int id;

  /// The name of the detector.
  final String name;

  /// The corners of the detector in the focal plane.
  final List<Offset> corners;

  /// The bounding box that contains the full [Detector].
  final Rect bbox;

  Detector({
    required this.id,
    required this.name,
    required this.corners,
    required this.bbox,
  });

  /// Create a [Detector] from a list of corners.
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

  /// Convert the [Detector] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "corners": corners.map((corner) {
        return [corner.dx, corner.dy];
      }).toList(),
    };
  }

  /// Parse the [Detector] from a JSON object.
  static Detector fromJson(Map<String, dynamic> json) {
    return Detector(
      id: json["id"],
      name: json["name"],
      corners: (json["corners"] as List).map((corner) {
        return Offset(corner[0], corner[1]);
      }).toList(),
      bbox: Rect.fromLTRB(
        json["corners"].map((corner) => corner[0]).reduce((a, b) => a < b ? a : b),
        json["corners"].map((corner) => corner[1]).reduce((a, b) => a < b ? a : b),
        json["corners"].map((corner) => corner[0]).reduce((a, b) => a > b ? a : b),
        json["corners"].map((corner) => corner[1]).reduce((a, b) => a > b ? a : b),
      ),
    );
  }
}
