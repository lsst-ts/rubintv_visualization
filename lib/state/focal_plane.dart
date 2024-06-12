import 'package:flutter/material.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/image/focal_plane.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class Instrument {
  final String name;
  final List<Detector> detectors;

  Instrument({
    required this.name,
    required this.detectors,
  });

  static Instrument fromJson(Map<String, dynamic> json) {
    return Instrument(
      name: json["instrument"],
      detectors: (json["detectors"] as List).map((detector) {
        return Detector.fromCorners(
          id: detector["id"],
          name: detector["name"],
          corners: (detector["corners"] as List).map((corner) {
            return Offset(corner[0], corner[1]);
          }).toList(),
        );
      }).toList(),
    );
  }
}

class FocalPlaneWindow extends Window {
  final Instrument instrument;

  FocalPlaneWindow({
    super.key,
    required super.id,
    required super.offset,
    super.title,
    required super.size,
    required this.instrument,
  });

  @override
  FocalPlaneWindow copyWith({
    UniqueId? id,
    Offset? offset,
    String? title,
    Size? size,
    Instrument? instrument,
  }) {
    return FocalPlaneWindow(
      key: key,
      id: id ?? this.id,
      offset: offset ?? this.offset,
      title: title ?? this.title,
      size: size ?? this.size,
      instrument: instrument ?? this.instrument,
    );
  }

  @override
  Widget? createToolbar(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);

    return Row(children: [
      Container(
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
        child: Tooltip(
          message: "Remove chart",
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              workspace.dispatch(RemoveWindowAction(this));
            },
          ),
        ),
      )
    ]);
  }

  @override
  Widget createWidget(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: FocalPlaneViewer(instrument: instrument, selectedDetector: workspace.info.detector),
    );
  }
}
