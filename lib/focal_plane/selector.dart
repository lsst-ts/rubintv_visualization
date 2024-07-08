import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/focal_plane/viewer.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class DetectorSelector extends StatelessWidget {
  final Window window;
  final WorkspaceState workspace;

  const DetectorSelector({
    super.key,
    required this.window,
    required this.workspace,
  });

  @override
  Widget build(BuildContext context) {
    return ResizableWindow(
      info: window,
      toolbar: Container(
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
        child: Tooltip(
          message: "Remove chart",
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              context.read<WorkspaceBloc>().add(RemoveWindowEvent(window.id));
            },
          ),
        ),
      ),
      title: workspace.instrument!.name,
      child: SizedBox(
        width: window.size.width,
        height: window.size.height,
        child: FocalPlaneViewer(
          window: window,
          instrument: workspace.instrument!,
          selectedDetector: workspace.detector,
          workspace: workspace,
        ),
      ),
    );
  }
}
