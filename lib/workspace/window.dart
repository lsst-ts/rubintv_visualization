import 'package:flutter/material.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/theme.dart';

/// Different sides that can be resized
enum WindowResizeDirections {
  left,
  right,
  down,
  downLeft,
  downRight,
}

/// A callback when a window has been updated
typedef WindowUpdateCallback = void Function(WindowUpdate update);

/// Information about window interactions
class WindowInteractionInfo {
  final UniqueId id;
  Offset offset;
  Size size;

  WindowInteractionInfo({
    required this.id,
    required this.offset,
    required this.size,
  });
}

class WindowDragInfo extends WindowInteractionInfo {
  final Offset pointerOffset;

  WindowDragInfo({
    required super.id,
    required this.pointerOffset,
    required super.offset,
    required super.size,
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
    required super.offset,
    required super.size,
  });
}

/// An update to the window (either a resize or translation).
class WindowUpdate {
  const WindowUpdate();
}

/// Update when a window is first being dragged.
class StartDragWindowUpdate extends WindowUpdate {
  final UniqueId windowId;
  final DragStartDetails details;

  const StartDragWindowUpdate({
    required this.windowId,
    required this.details,
  });
}

/// Update when a window is being dragged.
class UpdateDragWindowUpdate extends WindowUpdate {
  final UniqueId windowId;
  final DragUpdateDetails details;

  const UpdateDragWindowUpdate({
    required this.windowId,
    required this.details,
  });
}

/// Update when the drag pointer has been removed and the window is no longer being dragged.
class WindowDragEnd extends WindowUpdate {
  final UniqueId windowId;
  final DragEndDetails details;

  const WindowDragEnd({
    required this.windowId,
    required this.details,
  });
}

/// A window has started to be resized
class StartWindowResize extends WindowUpdate {
  final UniqueId windowId;
  final DragStartDetails details;

  StartWindowResize({
    required this.windowId,
    required this.details,
  });
}

/// [WindowUpdate] to update the size of a [Window] in the parent [WorkspaceViewer].
class UpdateWindowResize extends WindowUpdate {
  final UniqueId windowId;
  final DragUpdateDetails details;
  final WindowResizeDirections direction;

  const UpdateWindowResize({
    required this.windowId,
    required this.details,
    required this.direction,
  });
}

/// The window has finished resizing.
class EndWindowResize extends WindowUpdate {
  final UniqueId windowId;
  final DragEndDetails details;

  const EndWindowResize({
    required this.windowId,
    required this.details,
  });
}

/// Apply an update to a [Window] to the main [AppState].
class ApplyWindowUpdate extends UiAction {
  final UniqueId windowId;
  final Offset offset;
  final Size size;

  ApplyWindowUpdate({
    required this.windowId,
    required this.offset,
    required this.size,
  });
}

/// Draw the title (drag) bar above the window.
class WindowTitle extends StatelessWidget {
  /// The text to display in the title
  final String? text;

  /// The [AppTheme] for the app.
  final AppTheme theme;
  final Widget? toolbar;

  const WindowTitle({
    super.key,
    required this.text,
    required this.theme,
    this.toolbar,
  });

  @override
  Widget build(BuildContext context) {
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
                  print("Open menu");
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
              print("Open menu");
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
class RemoveWindowAction extends UiAction {
  final Window window;
  const RemoveWindowAction(this.window);
}

/// A single, persistable, item displayed in a [Workspace].
abstract class Window {
  /// The [id] of this [Window] in [Workspace.windows].
  final UniqueId id;

  /// The location of the window in the entire workspace
  final Offset offset;

  /// The size of the entry in the entire workspace
  final Size size;

  /// The title to display in the window bar.
  final String? title;

  const Window({
    required this.id,
    required this.offset,
    required this.size,
    this.title,
  });

  Window copyWith({
    UniqueId? id,
    Offset? offset,
    Size? size,
    String? title,
  });

  /// Create a new [Widget] to display in a [Workspace].
  Widget createWidget(BuildContext context);

  Widget? createToolbar(BuildContext context);
}

class ResizableWindow extends StatelessWidget {
  /// The child [Widget] to display in the window.
  final Widget child;

  /// The title to display in the window
  final String? title;

  /// The full size of the window, including the [WindowTitle].
  /// If [size] is null then the window will layout the child first and expand to the child size.
  final Size size;

  /// The [AppTheme] for the app.
  final AppTheme theme;

  /// Information about the widget
  final Window info;

  /// Callback to notify the [WorkspaceViewer] that this [Window] has been updated.
  final WindowUpdateCallback dispatch;

  /// Toolbar associated with the window
  final Widget? toolbar;

  const ResizableWindow({
    super.key,
    required this.child,
    required this.title,
    required this.theme,
    required this.info,
    required this.size,
    required this.dispatch,
    required this.toolbar,
  });

  void _onResizeStart(DragStartDetails details) {
    dispatch(StartWindowResize(windowId: info.id, details: details));
  }

  DragUpdateCallback _onResizeUpdate(WindowResizeDirections direction) {
    return (DragUpdateDetails details) {
      dispatch(UpdateWindowResize(
        windowId: info.id,
        details: details,
        direction: direction,
      ));
    };
  }

  void _onResizeEnd(DragEndDetails details) {
    dispatch(EndWindowResize(windowId: info.id, details: details));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: theme.themeData.colorScheme.background,
        child: IntrinsicWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          GestureDetector(
            onPanStart: (DragStartDetails details) {
              dispatch(StartDragWindowUpdate(windowId: info.id, details: details));
            },
            onPanUpdate: (DragUpdateDetails details) {
              dispatch(UpdateDragWindowUpdate(windowId: info.id, details: details));
            },
            onPanEnd: (DragEndDetails details) {
              dispatch(WindowDragEnd(windowId: info.id, details: details));
            },
            child: WindowTitle(
              text: title,
              theme: theme,
              toolbar: toolbar,
            ),
          ),
          SizedBox(
            width: size.width,
            height: size.height,
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
                  onHorizontalDragStart: _onResizeStart,
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.left),
                  onHorizontalDragEnd: _onResizeEnd,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: SizedBox(
                      height: size.height,
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
                  onHorizontalDragStart: _onResizeStart,
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.right),
                  onHorizontalDragEnd: _onResizeEnd,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: SizedBox(
                      height: size.height,
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
                  onHorizontalDragStart: _onResizeStart,
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.down),
                  onHorizontalDragEnd: _onResizeEnd,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeUpDown,
                    child: SizedBox(
                      height: theme.resizeInteractionWidth,
                      width: size.width,
                    ),
                  ),
                ),
              ),

              // bottom-left resize
              Positioned(
                left: 0,
                bottom: 0,
                child: GestureDetector(
                  onHorizontalDragStart: _onResizeStart,
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.downLeft),
                  onHorizontalDragEnd: _onResizeEnd,
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
                  onHorizontalDragStart: _onResizeStart,
                  onHorizontalDragUpdate: _onResizeUpdate(WindowResizeDirections.downRight),
                  onHorizontalDragEnd: _onResizeEnd,
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
