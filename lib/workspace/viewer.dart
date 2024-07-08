import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/chart/binned.dart';
import 'package:rubintv_visualization/chart/scatter.dart';
import 'package:rubintv_visualization/focal_plane/chart.dart';
import 'package:rubintv_visualization/focal_plane/selector.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/controller.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/toolbar.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// A [Widget] used to display a set of re-sizable and translatable [Window] widgets in a container.
class WorkspaceViewer extends StatefulWidget {
  final Size size;
  final AppTheme theme;

  const WorkspaceViewer({
    super.key,
    required this.size,
    required this.theme,
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

class WorkspaceViewerState extends State<WorkspaceViewer> {
  AppTheme get theme => widget.theme;
  Size get size => widget.size;

  WorkspaceState? info;

  @override
  void initState() {
    developer.log("Initializing WorkspaceViewerState", name: "rubin_chart.workspace");
    super.initState();

    ControlCenter().selectionController.subscribe(_onSelectionUpdate);
  }

  /// Update the selection data points.
  /// This isn't used now, but can be used in the future if any plots cannot be
  /// matched to obs_date,seq_num data IDs.
  void _onSelectionUpdate(Set<Object> dataPoints) {
    developer.log("Selection updated: ${dataPoints.length}", name: "rubin_chart.workspace");
    /*info.webSocket!.sink.add(SelectDataPointsCommand(
      dataPoints: dataPoints as Set<DataId>,
    ).toJson());*/
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WorkspaceBloc()..add(InitializeWorkspaceEvent(theme)),
      child: BlocBuilder<WorkspaceBloc, WorkspaceStateBase>(
        builder: (context, state) {
          if (state is WorkspaceStateInitial) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state is WorkspaceState) {
            info = state;
            return Column(children: [
              Toolbar(workspace: state),
              SizedBox(
                width: size.width,
                height: size.height - 2 * kToolbarHeight,
                child: Builder(
                  builder: (BuildContext context) {
                    List<Widget> children = [];
                    for (Window window in info!.windows.values) {
                      children.add(Positioned(
                        left: window.offset.dx,
                        top: window.offset.dy,
                        child: buildWindow(window, state),
                      ));
                    }

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

  Widget buildWindow(Window window, WorkspaceState state) {
    if (window.type == WindowTypes.cartesianScatter || window.type == WindowTypes.polarScatter) {
      return ScatterPlotWidget(window: window);
    }
    if (window.type == WindowTypes.histogram || window.type == WindowTypes.box) {
      return BinnedChartWidget(window: window);
    }
    if (window.type == WindowTypes.detectorSelector) {
      return DetectorSelector(
        window: window,
        workspace: state,
      );
    }
    if (window.type == WindowTypes.focalPlane) {
      return FocalPlaneChartViewer(
        window: window,
        workspace: state,
      );
    }
    throw UnimplementedError("WindowType ${window.type} is not implemented yet");
  }
}
