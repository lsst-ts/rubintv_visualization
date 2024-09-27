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
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/focal_plane/viewer.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// A [Widget] used to display a [DetectorSelector] in a container.
class DetectorSelector extends StatelessWidget {
  /// The [WindowMetaData] to display the [DetectorSelector] in.
  final WindowMetaData window;

  /// The [WorkspaceState].
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
