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
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/chart/binned.dart';
import 'package:rubintv_visualization/focal_plane/chart.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';

/// The type of chart to display.
enum WindowTypes {
  detectorSelector,
  focalPlane,
  histogram,
  box,
  cartesianScatter,
  polarScatter,
  combination;

  /// Return true if the window is a chart.
  bool get isChart => this != WindowTypes.detectorSelector;

  // Return true if the window is a scatter plot.
  bool get isScatter => this == WindowTypes.cartesianScatter || this == WindowTypes.polarScatter;

  /// Return true if the window is a binned chart.
  bool get isBinned => this == WindowTypes.histogram || this == WindowTypes.box;

  /// Create a [WindowTypes] from a string.
  static WindowTypes fromString(String value) => WindowTypes.values.firstWhere((e) => e.name == value);
}

/// Abstract window event
abstract class WindowEvent {}

/// State of a window.
class WindowState {
  /// All windows have a [UniqueId].
  UniqueId id;

  /// The type of window to display.
  final WindowTypes windowType;

  WindowState({
    required this.id,
    required this.windowType,
  });

  /// Convert the state to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      "id": id.toSerializableString(),
      "windowType": windowType.toString(),
    };
  }

  /// Create a [WindowState] from a JSON object.
  factory WindowState.fromJson(Map<String, dynamic> json, ChartTheme theme) {
    WindowTypes windowType = WindowTypes.fromString(json["windowType"]);

    late WindowState result;

    if (windowType.isScatter) {
      result = ChartState.fromJson(json);
    } else if (windowType.isBinned) {
      result = BinnedState.fromJson(json);
    } else if (windowType == WindowTypes.focalPlane) {
      result = FocalPlaneChartState.fromJson(json, theme);
    } else {
      throw ArgumentError("Unrecognized window type $windowType");
    }
    return result;
  }
}

/// Abstract window bloc
class WindowBloc<T extends WindowState> extends Bloc<WindowEvent, T> {
  WindowBloc(super.initialState);
}

/// A single, persistable, item displayed in a [Workspace].
@immutable
class WindowMetaData {
  /// The location of the window in the entire workspace
  final Offset offset;

  /// The size of the entry in the entire workspace
  final Size size;

  /// The title to display in the window bar.
  final String? title;

  /// The [WindowBloc] associated with this window
  final WindowBloc bloc;

  const WindowMetaData({
    required this.offset,
    required this.size,
    required this.bloc,
    this.title,
  });

  /// Create a copy of the [WindowMetaData] with the provided fields updated.
  WindowMetaData copyWith({
    Offset? offset,
    Size? size,
    WindowBloc? bloc,
    String? title,
  }) =>
      WindowMetaData(
        offset: offset ?? this.offset,
        size: size ?? this.size,
        title: title ?? this.title,
        bloc: bloc ?? this.bloc,
      );

  @override
  String toString() {
    return "Window(id: $id, offset: $offset, size: $size, title: $title, type: $windowType)";
  }

  /// The [id] of this [WindowMetaData] in [Workspace.windows].
  UniqueId get id => bloc.state.id;

  /// The type of window to display.
  WindowTypes get windowType => bloc.state.windowType;

  /// Convert the [WindowMetaData] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      "state": bloc.state.toJson(),
      "offset": {"dx": offset.dx, "dy": offset.dy},
      "size": {"width": size.width, "height": size.height},
      "title": title,
    };
  }

  /// Create a [WindowMetaData] from a JSON object.
  static WindowMetaData fromJson(Map<String, dynamic> json, ChartTheme theme) {
    WindowState state = WindowState.fromJson(json["state"], theme);
    Offset offset = Offset(json["offset"]["dx"], json["offset"]["dy"]);
    Size size = Size(json["size"]["width"], json["size"]["height"]);
    String? title = json["title"] == "" ? null : json["title"];
    late WindowBloc bloc;
    if (state.windowType == WindowTypes.detectorSelector) {
      bloc = WindowBloc(state);
    } else if (state.windowType.isBinned) {
      bloc = ChartBloc(state as BinnedState);
    } else if (state.windowType.isScatter) {
      bloc = ChartBloc(state as ChartState);
    } else if (state.windowType == WindowTypes.focalPlane) {
      bloc = FocalPlaneChartBloc(state as FocalPlaneChartState);
    } else {
      throw ArgumentError("Unrecognized window type ${state.windowType}");
    }
    return WindowMetaData(offset: offset, size: size, title: title, bloc: bloc);
  }
}

/// Different sides that can be resized
enum WindowResizeDirections {
  left,
  right,
  down,
  downLeft,
  downRight,
}

/// Information about window interactions
class WindowInteractionInfo {
  final UniqueId id;

  WindowInteractionInfo({
    required this.id,
  });
}

/// Information about a window being dragged.
class WindowDragInfo extends WindowInteractionInfo {
  /// The offset of the pointer from the top-left corner of the window.
  final Offset pointerOffset;

  WindowDragInfo({
    required super.id,
    required this.pointerOffset,
  });
}

/// Information about a window being resized.
class WindowResizeInfo extends WindowInteractionInfo {
  /// The offset of the pointer from the top-left corner of the window when it first contacted the window.
  final Offset initialPointerOffset;

  /// The initial size of the window.
  final Size initialSize;

  /// The initial offset of the window in the workspace.
  final Offset initialOffset;

  WindowResizeInfo({
    required super.id,
    required this.initialPointerOffset,
    required this.initialSize,
    required this.initialOffset,
  });
}

/// Update when a window is first being dragged.
class WindowDragStartEvent extends WorkspaceEvent {
  /// The [UniqueId] of the window being dragged.
  final UniqueId windowId;

  /// The details of the drag start.
  final DragStartDetails details;

  WindowDragStartEvent({
    required this.windowId,
    required this.details,
  });
}

/// Update when a window is being dragged.
class WindowDragUpdate extends WorkspaceEvent {
  /// The [UniqueId] of the window being dragged.
  final UniqueId windowId;

  /// The details of the drag update.
  final DragUpdateDetails details;

  WindowDragUpdate({
    required this.windowId,
    required this.details,
  });
}

/// Update when the drag pointer has been removed and the window is no longer being dragged.
class WindowDragEndEvent extends WorkspaceEvent {
  /// The [UniqueId] of the window being dragged.
  final UniqueId windowId;

  /// The details of the drag end.
  final DragEndDetails details;

  WindowDragEndEvent({
    required this.windowId,
    required this.details,
  });
}

/// A window has started to be resized
class StartWindowResize extends WorkspaceEvent {
  /// The [UniqueId] of the window being resized.
  final UniqueId windowId;

  /// The details of the drag start.
  final DragStartDetails details;

  StartWindowResize({
    required this.windowId,
    required this.details,
  });
}

/// [WindowUpdate] to update the size of a [WindowMetaData] in the parent [WorkspaceViewer].
class UpdateWindowResize extends WorkspaceEvent {
  /// The [UniqueId] of the window being resized.
  final UniqueId windowId;

  /// The details of the drag update.
  final DragUpdateDetails details;

  //// The direction of the resize
  final WindowResizeDirections direction;

  UpdateWindowResize({
    required this.windowId,
    required this.details,
    required this.direction,
  });
}

/// The window has finished resizing.
class EndWindowResize extends WorkspaceEvent {
  /// The [UniqueId] of the window being resized.
  final UniqueId windowId;

  /// The details of the drag end.
  final DragEndDetails details;

  EndWindowResize({
    required this.windowId,
    required this.details,
  });
}

/// Draw the title (drag) bar above the window.
class WindowTitle extends StatelessWidget {
  /// The text to display in the title
  final String? text;

  /// The toolbar to display in the title
  final Widget? toolbar;

  const WindowTitle({
    super.key,
    required this.text,
    this.toolbar,
  });

  @override
  Widget build(BuildContext context) {
    AppTheme theme = WorkspaceViewer.of(context).info!.theme;
    if (toolbar != null) {
      return Container(
          constraints: const BoxConstraints(
            minHeight: kMinInteractiveDimension,
          ),
          decoration: BoxDecoration(
            color: theme.themeData.colorScheme.primaryContainer,
          ),
          child: Row(children: [
            IconButton(
                icon: Icon(
                  Icons.menu,
                  color: theme.titleStyle.color,
                  size: kMinInteractiveDimension * .7,
                ),
                onPressed: () {
                  developer.log("Open menu", name: "rubinTV.visualization.workspace.window");
                }),
            Expanded(
              child: Center(
                child: Text(text ?? "", style: theme.titleStyle, textAlign: TextAlign.center),
              ),
            ),
            toolbar!,
          ]));
    }

    return Container(
      constraints: const BoxConstraints(
        minHeight: kMinInteractiveDimension,
      ),
      decoration: BoxDecoration(
        color: theme.themeData.colorScheme.primaryContainer,
      ),
      child: Row(children: [
        IconButton(
            icon: Icon(
              Icons.menu,
              color: theme.titleStyle.color,
              size: kMinInteractiveDimension * .7,
            ),
            onPressed: () {
              developer.log("Open menu", name: "rubinTV.visualization.workspace.window");
            }),
        Expanded(
          child: Center(
            child: Text(text ?? "", style: theme.titleStyle, textAlign: TextAlign.center),
          ),
        ),
      ]),
    );
  }
}

/// Remove a [Chart] from the [Workspace].
class RemoveWindowEvent extends WorkspaceEvent {
  /// The [UniqueId] of the window to remove.
  final UniqueId windowId;

  RemoveWindowEvent(this.windowId);
}

/// A [Widget] that can be resized and dragged around a workspace.
class ResizableWindow extends StatelessWidget {
  /// The child [Widget] to display in the window.
  final Widget child;

  /// The title to display in the window
  final String? title;

  /// Information about the widget
  final WindowMetaData info;

  /// Toolbar associated with the window
  final Widget? toolbar;

  const ResizableWindow({
    super.key,
    required this.child,
    required this.title,
    required this.info,
    required this.toolbar,
  });

  /// Notify the [WorkspaceBloc] that the window is being dragged.
  void _onResizeStart(DragStartDetails details, BuildContext context) {
    context.read<WorkspaceBloc>().add(StartWindowResize(windowId: info.id, details: details));
  }

  /// Notify the [WorkspaceBloc] that the window is being resized.
  DragUpdateCallback _onResizeUpdate(WindowResizeDirections direction, BuildContext context) {
    return (DragUpdateDetails details) {
      context.read<WorkspaceBloc>().add(UpdateWindowResize(
            windowId: info.id,
            details: details,
            direction: direction,
          ));
    };
  }

  /// Notify the [WorkspaceBloc] that the window is no longer being resized.
  void _onResizeEnd(DragEndDetails details, BuildContext context) {
    context.read<WorkspaceBloc>().add(EndWindowResize(windowId: info.id, details: details));
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = WorkspaceViewer.of(context).info!.theme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: theme.themeData.colorScheme.surface,
        child: IntrinsicWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GestureDetector(
            onPanStart: (DragStartDetails details) {
              context.read<WorkspaceBloc>().add(WindowDragStartEvent(windowId: info.id, details: details));
            },
            onPanUpdate: (DragUpdateDetails details) {
              context.read<WorkspaceBloc>().add(WindowDragUpdate(windowId: info.id, details: details));
            },
            onPanEnd: (DragEndDetails details) {
              context.read<WorkspaceBloc>().add(WindowDragEndEvent(windowId: info.id, details: details));
            },
            child: WindowTitle(
              text: title,
              toolbar: toolbar,
            ),
          ),
          SizedBox(
            width: info.size.width,
            height: info.size.height,
            child: Stack(children: [
              Container(
                margin: const EdgeInsets.all(5),
                child: child,
              ),

              // Left resize
              Positioned(
                left: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (DragStartDetails details) {
                    _onResizeStart(details, context);
                  },
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.left, context),
                  onHorizontalDragEnd: (DragEndDetails details) {
                    _onResizeEnd(details, context);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: SizedBox(
                      height: info.size.height,
                      width: theme.resizeInteractionWidth,
                    ),
                  ),
                ),
              ),

              // right resize
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (DragStartDetails details) {
                    _onResizeStart(details, context);
                  },
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.right, context),
                  onHorizontalDragEnd: (DragEndDetails details) {
                    _onResizeEnd(details, context);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: SizedBox(
                      height: info.size.height,
                      width: theme.resizeInteractionWidth,
                    ),
                  ),
                ),
              ),

              // bottom resize
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (DragStartDetails details) {
                    _onResizeStart(details, context);
                  },
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.down, context),
                  onHorizontalDragEnd: (DragEndDetails details) {
                    _onResizeEnd(details, context);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: SizedBox(
                      height: theme.resizeInteractionWidth,
                      width: info.size.width,
                    ),
                  ),
                ),
              ),

              // bottom-left resize
              Positioned(
                left: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (DragStartDetails details) {
                    _onResizeStart(details, context);
                  },
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.downLeft, context),
                  onHorizontalDragEnd: (DragEndDetails details) {
                    _onResizeEnd(details, context);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownLeft,
                    child: SizedBox(
                      height: theme.resizeInteractionWidth,
                      width: theme.resizeInteractionWidth,
                    ),
                  ),
                ),
              ),

              // bottom-right resize
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: (DragStartDetails details) {
                    _onResizeStart(details, context);
                  },
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.downRight, context),
                  onHorizontalDragEnd: (DragEndDetails details) {
                    _onResizeEnd(details, context);
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeDownRight,
                    child: SizedBox(
                      height: theme.resizeInteractionWidth,
                      width: theme.resizeInteractionWidth,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ])),
      ),
    );
  }
}
