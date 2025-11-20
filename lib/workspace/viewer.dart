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

import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/chart/binned.dart';
import 'package:rubintv_visualization/chart/scatter.dart';
import 'package:rubintv_visualization/focal_plane/chart.dart';
import 'package:rubintv_visualization/focal_plane/selector.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/toolbar.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// A [Widget] used to display a set of re-sizable and translatable [WindowMetaData] widgets in a container.
class WorkspaceViewer extends StatefulWidget {
  /// The size of the widget.
  final Size size;

  /// The theme to use for the workspace.
  final AppTheme theme;

  /// The current version of the application.
  final AppVersion version;

  const WorkspaceViewer({
    super.key,
    required this.size,
    required this.theme,
    required this.version,
  });

  @override
  WorkspaceViewerState createState() => WorkspaceViewerState();

  /// Implement the [WorkspaceViewer.of] method to allow children
  /// to find this container based on their [BuildContext].
  static WorkspaceViewerState of(BuildContext context) {
    final WorkspaceViewerState? result = context.findAncestorStateOfType<WorkspaceViewerState>();
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('WorkspaceViewer.of() called with a context that does not '
              'contain a WorkspaceViewer.'),
          ErrorDescription('No WorkspaceViewer ancestor could be found starting from the context '
              'that was passed to WorkspaceViewer.of().'),
          ErrorHint('This probably happened when an interactive child was created '
              'outside of an WorkspaceViewer'),
          context.describeElement('The context used was')
        ]);
      }
      return true;
    }());
    return result!;
  }
}

/// The state of the [WorkspaceViewer] widget.
class WorkspaceViewerState extends State<WorkspaceViewer> {
  AppTheme get theme => widget.theme;
  Size get size => widget.size;
  AppVersion get version => widget.version;

  /// The current state of the workspace.
  WorkspaceState? info;
  UniqueKey get id => UniqueKey();

  @override
  void initState() {
    developer.log("=== INITIALIZING WORKSPACE VIEWER ===", name: "rubintv.workspace.viewer");
    super.initState();

    ControlCenter().selectionController.subscribe(id, _onSelectionUpdate);
  }

  /// Update the selection data points.
  /// This isn't used now, but can be used in the future if any plots cannot be
  /// matched to obs_date,seq_num data IDs.
  void _onSelectionUpdate(Object? origin, Set<Object> dataPoints) {
    developer.log("Workspace viewer received selection update from $origin: ${dataPoints.length} points",
        name: "rubintv.workspace.viewer");
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WorkspaceBloc()..add(InitializeWorkspaceEvent(theme, version)),
      child: BlocBuilder<WorkspaceBloc, WorkspaceStateBase>(
        builder: (context, state) {
          developer.log("=== BUILDING WORKSPACE ===", name: "rubintv.workspace.viewer");
          developer.log("State type: ${state.runtimeType}", name: "rubintv.workspace.viewer");

          if (state is WorkspaceStateInitial) {
            developer.log("Workspace state is initial - showing progress indicator",
                name: "rubintv.workspace.viewer");
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          info = state as WorkspaceState?;
          if (state is WorkspaceState) {
            developer.log(
                "Workspace state loaded: ${state.windows.length} windows, instrument=${state.instrument?.name}",
                name: "rubintv.workspace.viewer");
            return Column(children: [
              Toolbar(workspace: state),
              SizedBox(
                width: size.width,
                height: size.height - kToolbarHeight,
                child: Builder(
                  builder: (BuildContext context) {
                    List<Widget> children = [];
                    for (WindowMetaData window in state.windows.values) {
                      developer.log("Building window ${window.id} of type ${window.windowType}",
                          name: "rubintv.workspace.viewer");
                      children.add(Positioned(
                        left: window.offset.dx,
                        top: window.offset.dy,
                        child: buildWindow(window, state),
                      ));
                    }
                    developer.log("Built ${children.length} windows", name: "rubintv.workspace.viewer");

                    return Stack(
                      children: children,
                    );
                  },
                ),
              ),
            ]);
          }

          throw ArgumentError("Unrecognized WorkspaceState $state");
        },
      ),
    );
  }

  /// Build a window widget based on the type of the window.
  Widget buildWindow(WindowMetaData window, WorkspaceState workspace) {
    developer.log("Building window widget for ${window.id} type ${window.windowType}",
        name: "rubintv.workspace.viewer");

    if (window.windowType == WindowTypes.cartesianScatter || window.windowType == WindowTypes.polarScatter) {
      return ScatterPlotWidget(window: window, bloc: window.bloc as ChartBloc);
    }
    if (window.windowType == WindowTypes.histogram || window.windowType == WindowTypes.box) {
      return BinnedChartWidget(window: window, bloc: window.bloc as ChartBloc);
    }
    if (window.windowType == WindowTypes.detectorSelector) {
      return DetectorSelector(
        window: window,
        workspace: workspace,
      );
    }
    if (window.windowType == WindowTypes.focalPlane) {
      return FocalPlaneChartViewer(
        window: window,
        workspace: workspace,
        bloc: window.bloc as FocalPlaneChartBloc,
      );
    }
    throw UnimplementedError("WindowType ${window.windowType} is not implemented yet");
  }
}
