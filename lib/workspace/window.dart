import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/workspace.dart';

/// The type of chart to display.
enum WindowTypes {
  focalPlane,
  histogram,
  box,
  cartesianScatter,
  polarScatter,
  combination,
}

/// A single, persistable, item displayed in a [Workspace].
@immutable
class Window {
  /// The [id] of this [Window] in [Workspace.windows].
  final UniqueId id;

  /// The location of the window in the entire workspace
  final Offset offset;

  /// The size of the entry in the entire workspace
  final Size size;

  /// The title to display in the window bar.
  final String? title;

  final WindowTypes type;

  const Window({
    required this.id,
    required this.offset,
    required this.size,
    required this.type,
    this.title,
  });

  /// Create a copy of the [Window] with the provided fields updated.
  Window copyWith({
    UniqueId? id,
    Offset? offset,
    Size? size,
    String? title,
  }) =>
      Window(
        id: id ?? this.id,
        offset: offset ?? this.offset,
        size: size ?? this.size,
        title: title ?? this.title,
        type: type,
      );

  @override
  String toString() {
    return "Window(id: $id, offset: $offset, size: $size, title: $title, type: $type)";
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

class WindowDragInfo extends WindowInteractionInfo {
  final Offset pointerOffset;

  WindowDragInfo({
    required super.id,
    required this.pointerOffset,
  });
}

class WindowResizeInfo extends WindowInteractionInfo {
  final Offset initialPointerOffset;
  final Size initialSize;
  final Offset initialOffset;

  WindowResizeInfo({
    required super.id,
    required this.initialPointerOffset,
    required this.initialSize,
    required this.initialOffset,
  });
}

/// Update when a window is first being dragged.
class StartWindowDragEvent extends WorkspaceEvent {
  final UniqueId windowId;
  final DragStartDetails details;

  StartWindowDragEvent({
    required this.windowId,
    required this.details,
  });
}

/// Update when a window is being dragged.
class WindowDragUpdate extends WorkspaceEvent {
  final UniqueId windowId;
  final DragUpdateDetails details;

  WindowDragUpdate({
    required this.windowId,
    required this.details,
  });
}

/// Update when the drag pointer has been removed and the window is no longer being dragged.
class WindowDragEnd extends WorkspaceEvent {
  final UniqueId windowId;
  final DragEndDetails details;

  WindowDragEnd({
    required this.windowId,
    required this.details,
  });
}

/// A window has started to be resized
class StartWindowResize extends WorkspaceEvent {
  final UniqueId windowId;
  final DragStartDetails details;

  StartWindowResize({
    required this.windowId,
    required this.details,
  });
}

/// [WindowUpdate] to update the size of a [Window] in the parent [WorkspaceViewer].
class UpdateWindowResize extends WorkspaceEvent {
  final UniqueId windowId;
  final DragUpdateDetails details;
  final WindowResizeDirections direction;

  UpdateWindowResize({
    required this.windowId,
    required this.details,
    required this.direction,
  });
}

/// The window has finished resizing.
class EndWindowResize extends WorkspaceEvent {
  final UniqueId windowId;
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
  final UniqueId windowId;
  RemoveWindowEvent(this.windowId);
}

class ResizableWindow extends StatelessWidget {
  /// The child [Widget] to display in the window.
  final Widget child;

  /// The title to display in the window
  final String? title;

  /// Information about the widget
  final Window info;

  /// Toolbar associated with the window
  final Widget? toolbar;

  const ResizableWindow({
    super.key,
    required this.child,
    required this.title,
    required this.info,
    required this.toolbar,
  });

  void _onResizeStart(DragStartDetails details, BuildContext context) {
    context.read<WorkspaceBloc>().add(StartWindowResize(windowId: info.id, details: details));
  }

  DragUpdateCallback _onResizeUpdate(WindowResizeDirections direction, BuildContext context) {
    return (DragUpdateDetails details) {
      context.read<WorkspaceBloc>().add(UpdateWindowResize(
            windowId: info.id,
            details: details,
            direction: direction,
          ));
    };
  }

  void _onResizeEnd(DragEndDetails details, BuildContext context) {
    context.read<WorkspaceBloc>().add(EndWindowResize(windowId: info.id, details: details));
  }

  @override
  Widget build(BuildContext context) {
    AppTheme theme = WorkspaceViewer.of(context).info!.theme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: theme.themeData.colorScheme.background,
        child: IntrinsicWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GestureDetector(
            onPanStart: (DragStartDetails details) {
              context.read<WorkspaceBloc>().add(StartWindowDragEvent(windowId: info.id, details: details));
            },
            onPanUpdate: (DragUpdateDetails details) {
              context.read<WorkspaceBloc>().add(WindowDragUpdate(windowId: info.id, details: details));
            },
            onPanEnd: (DragEndDetails details) {
              context.read<WorkspaceBloc>().add(WindowDragEnd(windowId: info.id, details: details));
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
