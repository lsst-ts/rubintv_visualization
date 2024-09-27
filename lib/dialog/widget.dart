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
import 'package:rubintv_visualization/dialog/base.dart';
import 'package:rubintv_visualization/dialog/bloc.dart';

/// The action to be performed by the file dialog.
enum FileDialogAction {
  load,

  /// Load a file
  save,

  /// Save a file
}

/// A widget to display a file dialog.
class FileDialogWidget extends StatelessWidget {
  /// The action to be performed by the file dialog.
  final FileDialogAction action;

  /// The content of the file to be saved (if action == [FileDialogAction.save]).
  final String? content;

  /// The key for the widget.
  const FileDialogWidget({super.key, required this.action, this.content})
      : assert(action != FileDialogAction.save || content != null);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (context) =>
            FileDialogBloc()..add(const LoadDirectoryEvent([])),
        child: BlocBuilder<FileDialogBloc, FileDialogState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(child: Text('Error: ${state.error}'));
            }
            return FileDialogContent(
              action: action,
              content: content,
            );
          },
        ));
  }
}

/// A widget to display the content of the file dialog.
class FileDialogContent extends StatefulWidget {
  /// The action to be performed by the file dialog.
  final FileDialogAction action;

  /// The content of the file to be saved (if action == [FileDialogAction.save]).
  final String? content;

  const FileDialogContent({super.key, required this.action, this.content});

  @override
  FileDialogContentState createState() => FileDialogContentState();
}

/// The state of the [FileDialogContent].
class FileDialogContentState extends State<FileDialogContent> {
  /// The text controller for the file name input.
  final TextEditingController _textController = TextEditingController();

  /// The text controller for renaming a file or directory.
  final TextEditingController _renameController = TextEditingController();

  /// Whether the user is renaming a file or directory.
  bool isRenaming = false;

  /// The ID of the item being dragged.
  String? draggedItemId;

  /// The ID of the directory being highlighted (when an item is being dragged over it).
  String? highlightedDirectoryId;

  /// Initialize the state of the widget.
  @override
  void initState() {
    super.initState();
    _textController.text = context.read<FileDialogBloc>().state.filename ?? '';
    _renameController.text = "";
  }

  @override
  Widget build(BuildContext context) {
    _textController.text = context.read<FileDialogBloc>().state.filename ?? '';
    return BlocBuilder<FileDialogBloc, FileDialogState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.error != null) {
          return Center(child: Text('Error: ${state.error}'));
        }
        return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildFileNameInput(context, state),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildDirectoryTree(
                            context, state.root.root, state.root),
                      ),
                      const VerticalDivider(),
                      Expanded(
                        flex: 1,
                        child: _buildCurrentDirectory(context, state),
                      ),
                    ],
                  ),
                ),
                _buildActionButtons(context, state),
              ],
            ));
      },
    );
  }

  /// Build the file name input.
  Widget _buildFileNameInput(BuildContext context, FileDialogState state) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _textController,
        decoration: const InputDecoration(
          labelText: 'File Name',
          border: OutlineInputBorder(),
        ),
        onEditingComplete: () {
          context
              .read<FileDialogBloc>()
              .add(UpdateFilenameEvent(_textController.text));
        },
      ),
    );
  }

  /// Build the directory tree pane.
  Widget _buildDirectoryTree(
      BuildContext context, DirectoryElement directory, RootDirectory root) {
    return ListView(
      children: [
        _buildDirectoryTreeItem(context, directory, root, 0),
      ],
    );
  }

  /// Rename a directory.
  void _renameDirectory(List<String> path, String value) {
    setState(() {
      isRenaming = false;
    });
    if (value.isEmpty) {
      return;
    }
    context.read<FileDialogBloc>().add(RenameFileEvent(
          path,
          value,
        ));
  }

  /// Build an item in the directory tree.
  /// This can either be a file or a directory, in which case it will
  /// recursively build the children of the directory.
  Widget _buildDirectoryTreeItem(BuildContext context,
      DirectoryElement directory, RootDirectory root, int depth) {
    FileDialogState state = context.read<FileDialogBloc>().state;
    bool isSelected = state.currentDirectoryId == directory.id &&
        state.currentDirectoryId != root.rootId &&
        state.selectedFile == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 16.0),
          child:
              _buildDraggableDirectoryItem(directory, root, state, isSelected),
        ),
        // Only build the children if the directory is expanded
        if (directory.isExpanded)
          ...root.getChildrenOfDirectory(directory.id).map((element) {
            if (element is DirectoryElement) {
              return _buildDirectoryTreeItem(context, element, root, depth + 1);
            } else {
              return Padding(
                padding: EdgeInsets.only(left: (depth + 1) * 16.0),
                child: _buildDraggableFileItem(element, root, state),
              );
            }
          }),
      ],
    );
  }

  /// Build a draggable directory item.
  Widget _buildDraggableDirectoryItem(DirectoryElement directory,
      RootDirectory root, FileDialogState state, bool isSelected) {
    return LongPressDraggable<String>(
      data: directory.id,
      // The feedback widget is what the user sees when they drag the item
      feedback: Material(
        elevation: 4.0,
        child: Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.grey[300],
          child: Text(directory.name),
        ),
      ),
      // Dim the item in the tree when it is being dragged
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildDirectoryItemContent(directory, root, state, isSelected),
      ),
      onDragStarted: () {
        setState(() {
          draggedItemId = directory.id;
        });
      },
      onDragEnd: (_) {
        setState(() {
          draggedItemId = null;
          highlightedDirectoryId = null;
        });
      },
      child: _buildDragTarget(
        directory.id,
        _buildDirectoryItemContent(directory, root, state, isSelected),
      ),
    );
  }

  /// Build the content of a directory item.
  Widget _buildDirectoryItemContent(DirectoryElement directory,
      RootDirectory root, FileDialogState state, bool isSelected) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
              directory.isExpanded ? Icons.expand_more : Icons.chevron_right),
          onPressed: () {
            context.read<FileDialogBloc>().add(
                ToggleExpandDirectoryEvent(root.getPathById(directory.id)));
          },
        ),
        Container(
          decoration: BoxDecoration(
            color: directory.id == highlightedDirectoryId
                ? Colors.blue[100]
                : (directory.id == state.currentDirectoryId && !isRenaming
                    ? Colors.grey[300]
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: isSelected && isRenaming
              ? SizedBox(
                  width: 200.0,
                  child: TextField(
                    autofocus: true,
                    controller: _renameController,
                    onSubmitted: (String value) {
                      if (value != directory.name) {
                        _renameDirectory(
                            state.root.getPathById(directory.id), value);
                      } else {
                        setState(() {
                          isRenaming = false;
                        });
                      }
                    },
                    onTapOutside: (PointerDownEvent event) {
                      String value = _renameController.text;
                      if (value != directory.name) {
                        _renameDirectory(
                            state.root.getPathById(directory.id), value);
                      } else {
                        setState(() {
                          isRenaming = false;
                        });
                      }
                    },
                  ),
                )
              : TextButton(
                  onPressed: () {
                    if (isSelected) {
                      setState(() {
                        isRenaming = true;
                        _renameController.text = directory.name;
                      });
                    }
                    context.read<FileDialogBloc>().add(
                        SelectDirectoryEvent(root.getPathById(directory.id)));
                    if (!directory.isExpanded) {
                      context.read<FileDialogBloc>().add(
                          ToggleExpandDirectoryEvent(
                              root.getPathById(directory.id)));
                    }
                  },
                  child: Text(directory.name == "" ? "/" : directory.name),
                ),
        ),
      ],
    );
  }

  /// Build a draggable file item.
  Widget _buildDraggableFileItem(
      FileElement file, RootDirectory root, FileDialogState state) {
    bool isSelected = state.selectedFile?.id == file.id;

    return LongPressDraggable<String>(
      data: file.id,
      feedback: Material(
        elevation: 4.0,
        child: Container(
          padding: const EdgeInsets.all(8.0),
          color: Colors.grey[300],
          child: Text(file.name),
        ),
      ),
      // Dim the item in the tree when it is being dragged
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: _buildFileItemContent(file, state, isSelected),
      ),
      onDragStarted: () {
        setState(() {
          draggedItemId = file.id;
        });
      },
      onDragEnd: (_) {
        setState(() {
          draggedItemId = null;
          highlightedDirectoryId = null;
        });
      },
      child: _buildFileItemContent(file, state, isSelected),
    );
  }

  /// Build the content of a file item.
  Widget _buildFileItemContent(
      FileElement file, FileDialogState state, bool isSelected) {
    return Container(
      decoration: BoxDecoration(
        color:
            isSelected && !isRenaming ? Colors.grey[300] : Colors.transparent,
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: ListTile(
        title: isSelected && isRenaming
            ? SizedBox(
                width: 200.0,
                child: TextField(
                  autofocus: true,
                  controller: _renameController,
                  onSubmitted: (String value) {
                    if (value != file.name) {
                      // Rename the directory if the user has changed the name
                      _renameDirectory(
                          state.root.getPathById(state.selectedFile!.id),
                          value);
                    } else {
                      isRenaming = false;
                    }
                    setState(() {});
                  },
                  onTapOutside: (PointerDownEvent event) {
                    String value = _renameController.text;
                    if (value != file.name) {
                      // Rename the directory if the user has changed the name
                      _renameDirectory(
                          state.root.getPathById(state.selectedFile!.id),
                          _renameController.text);
                    } else {
                      isRenaming = false;
                    }
                    setState(() {});
                  },
                ),
              )
            : Text(file.name),
        onTap: () {
          // Select the file when it is tapped
          if (state.selectedFile?.id == file.id) {
            setState(() {
              isRenaming = true;
              _renameController.text = file.name;
            });
          }
          context.read<FileDialogBloc>().add(SelectFileEvent(file.id));
        },
      ),
    );
  }

  /// Build a drag target for a directory item.
  Widget _buildDragTarget(String itemId, Widget child) {
    return DragTarget<String>(
      builder: (context, candidateData, rejectedData) {
        return child;
      },
      onWillAcceptWithDetails: (DragTargetDetails<String> details) {
        return details.data != itemId;
      },
      onAcceptWithDetails: (DragTargetDetails<String> details) {
        _showMoveConfirmationDialog(
            details.data, itemId, context.read<FileDialogBloc>());
      },
      onMove: (DragTargetDetails<String> details) {
        setState(() {
          highlightedDirectoryId = itemId;
        });
      },
      onLeave: (Object? data) {
        setState(() {
          highlightedDirectoryId = null;
        });
      },
    );
  }

  /// Show a dialog to confirm moving a file.
  void _showMoveConfirmationDialog(
      String sourceId, String targetId, FileDialogBloc bloc) {
    FileDialogState state = bloc.state;
    FileElement sourceElement = state.root.getElementById(sourceId)!;
    DirectoryElement targetDirectory =
        state.root.getElementById(targetId) as DirectoryElement;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Move Item"),
          content: Text(
              "Are you sure you want to move '${sourceElement.name}' to '${targetDirectory.name}'?"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Use the passed bloc instead of context.read
                bloc.add(MoveFileEvent(
                  state.root.getPathById(sourceId),
                  state.root.getPathById(targetId),
                ));
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Move'),
            ),
          ],
        );
      },
    );
  }

  /// Build the current directory pane.
  Widget _buildCurrentDirectory(BuildContext context, FileDialogState state) {
    List<String> path = state.root.getPathById(state.currentDirectoryId);
    DirectoryElement directory =
        state.root.getElementById(state.currentDirectoryId) as DirectoryElement;
    return Column(
      children: [
        ListTile(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: state.currentDirectoryId == state.root.rootId
                ? null
                : () {
                    context.read<FileDialogBloc>().add(
                        SelectDirectoryEvent(path.sublist(0, path.length - 1)));
                  },
          ),
          title: Text(path.join('/')),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: directory.childrenIds.length,
            itemBuilder: (context, index) {
              final List<String> childIds = directory.childrenIds;
              final FileElement item =
                  state.root.getElementById(childIds[index])!;
              final bool isDirectory = item is DirectoryElement;
              return ListTile(
                leading:
                    Icon(isDirectory ? Icons.folder : Icons.insert_drive_file),
                title: Text(item.name),
                onTap: () {
                  if (isDirectory) {
                    context.read<FileDialogBloc>().add(
                        SelectDirectoryEvent(state.root.getPathById(item.id)));
                  } else {
                    context
                        .read<FileDialogBloc>()
                        .add(UpdateFilenameEvent(item.name));
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build the action buttons
  /// (create directory, delete, duplicate, save, load, cancel).
  Widget _buildActionButtons(BuildContext context, FileDialogState state) {
    return OverflowBar(
      alignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: () {
            String newDirectory = _textController.text;
            if (newDirectory.isEmpty) {
              return;
            }
            _showConfirmationDialog(
              context: context,
              title: "Create Directrory",
              content:
                  "Are you sure you want to create a directory named $newDirectory?",
              onConfirm: () {
                context.read<FileDialogBloc>().add(CreateDirectoryEvent(
                      state.root.getPathById(state.currentDirectoryId),
                      newDirectory,
                    ));
              },
            );
          },
          child: const Text('Create Directory'),
        ),
        ElevatedButton(
          onPressed: state.selectedFile != null
              ? () {
                  String newFilename = _textController.text;
                  if (newFilename.isEmpty) {
                    return;
                  }
                  _showConfirmationDialog(
                    context: context,
                    title: "Delete file",
                    content:
                        "Are you sure you want to delete ${state.selectedFile!.name}",
                    onConfirm: () {
                      context.read<FileDialogBloc>().add(DeleteFileEvent(
                            state.root.getPathById(state.selectedFile!.id),
                          ));
                    },
                  );
                }
              : () {
                  DirectoryElement directory =
                      state.root.getElementById(state.currentDirectoryId)
                          as DirectoryElement;

                  _showConfirmationDialog(
                    context: context,
                    title: "Delete file",
                    content:
                        "Are you sure you want to delete ${directory.name}",
                    onConfirm: () {
                      context.read<FileDialogBloc>().add(DeleteFileEvent(
                            state.root.getPathById(directory.id),
                          ));
                    },
                  );
                },
          child: const Text('Delete'),
        ),
        ElevatedButton(
          onPressed: state.selectedFile != null
              ? () {
                  context.read<FileDialogBloc>().add(DuplicateFileEvent(
                      state.root.getPathById(state.selectedFile!.id)));
                }
              : null,
          child: const Text('Duplicate'),
        ),
        if (widget.action == FileDialogAction.save)
          ElevatedButton(
            onPressed: () {
              if (_textController.text.isEmpty) {
                return;
              }
              List<String> savePath =
                  state.root.getPathById(state.currentDirectoryId);
              savePath.add(_textController.text);
              context
                  .read<FileDialogBloc>()
                  .add(SaveFileEvent(savePath, widget.content!));
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        if (widget.action == FileDialogAction.load)
          ElevatedButton(
            onPressed: state.selectedFile != null
                ? () {
                    context.read<FileDialogBloc>().add(LoadFileEvent(
                        state.root.getPathById(state.selectedFile!.id)));
                    Navigator.of(context).pop();
                  }
                : null,
            child: const Text('Load'),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// Show a confirmation dialog.
  void _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Dismiss the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                onConfirm();
                Navigator.of(context).pop(); // Dismiss the dialog
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }
}
