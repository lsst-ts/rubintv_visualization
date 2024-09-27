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

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rubintv_visualization/dialog/base.dart';
import 'package:rubintv_visualization/error.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/utils.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:uuid/uuid.dart';

// File dialog events
abstract class FileDialogEvent {
  const FileDialogEvent();
}

/// Event to update the filename in the file dialog.
class UpdateFilenameEvent extends FileDialogEvent {
  final String filename;

  const UpdateFilenameEvent(this.filename);
}

/// Event to select a file in the file dialog.
class SelectFileEvent extends FileDialogEvent {
  final String fileId;

  const SelectFileEvent(this.fileId);
}

/// Event to toggle the expansion of a directory in the file dialog.
class ToggleExpandDirectoryEvent extends FileDialogEvent {
  final List<String> path;

  const ToggleExpandDirectoryEvent(this.path);
}

/// Event to select a directory in the file dialog.
class SelectDirectoryEvent extends FileDialogEvent {
  final List<String> path;

  const SelectDirectoryEvent(this.path);
}

/// Event to load a directory in the file dialog.
class LoadDirectoryEvent extends FileDialogEvent {
  final List<String> path;

  const LoadDirectoryEvent(this.path);
}

/// Event to create a directory in the file dialog.
class CreateDirectoryEvent extends FileDialogEvent {
  final List<String> path;
  final String name;

  const CreateDirectoryEvent(this.path, this.name);
}

/// Event to rename a file in the file dialog.
class RenameFileEvent extends FileDialogEvent {
  final List<String> path;
  final String newName;

  const RenameFileEvent(this.path, this.newName);
}

/// Event to delete a file in the file dialog.
class DeleteFileEvent extends FileDialogEvent {
  final List<String> path;

  const DeleteFileEvent(this.path);
}

/// Event to duplicate a file in the file dialog.
class DuplicateFileEvent extends FileDialogEvent {
  final List<String> path;

  const DuplicateFileEvent(this.path);
}

/// Event to move a file in the file dialog.
class MoveFileEvent extends FileDialogEvent {
  final List<String> sourcePath;
  final List<String> destinationPath;

  const MoveFileEvent(this.sourcePath, this.destinationPath);
}

/// Event to save a file in the file dialog.
class SaveFileEvent extends FileDialogEvent {
  final List<String> path;
  final String content;

  const SaveFileEvent(this.path, this.content);
}

/// Event to load a file in the file dialog.
class LoadFileEvent extends FileDialogEvent {
  final List<String> path;

  const LoadFileEvent(this.path);
}

/// Event to receive a message from the websocket.
class FileDialogReceiveMessageEvent extends FileDialogEvent {
  final Map<String, dynamic> message;

  const FileDialogReceiveMessageEvent(this.message);
}

/// Event to clear the selected file in the file dialog.
typedef FileDialogLoadCallback = void Function<T>(T value);

// State of the FileDialog widget
class FileDialogState<T> {
  /// The root directory of the file dialog.
  final RootDirectory root;

  /// The ID of the current directory.
  final String currentDirectoryId;

  /// The selected file in the file dialog.
  final FileElement? selectedFile;

  /// The error message to display.
  final String? error;

  /// Whether the file dialog is loading.
  final bool isLoading;

  /// The current filename.
  final String? filename;

  const FileDialogState({
    required this.root,
    required this.currentDirectoryId,
    this.selectedFile,
    this.error,
    this.isLoading = false,
    this.filename,
  });

  /// Initial state of the file dialog.
  factory FileDialogState.initial() {
    RootDirectory root = RootDirectory.empty();
    return FileDialogState(
      root: root,
      currentDirectoryId: root.root.id,
    );
  }

  FileDialogState copyWith({
    RootDirectory? root,
    String? currentDirectoryId,
    FileElement? selectedFile,
    String? error,
    bool? isLoading,
    String? filename,
  }) {
    return FileDialogState(
      root: root ?? this.root,
      currentDirectoryId: currentDirectoryId ?? this.currentDirectoryId,
      selectedFile: selectedFile ?? this.selectedFile,
      error: error,
      isLoading: isLoading ?? this.isLoading,
      filename: filename ?? this.filename,
    );
  }

  /// Clear the selected file in the file dialog.
  /// This is done outside of the [copyWith] method because
  /// the new [selectedFile] could be null.
  FileDialogState clearSelectedFile() {
    return FileDialogState(
      root: root,
      currentDirectoryId: currentDirectoryId,
      error: error,
      isLoading: isLoading,
    );
  }

  /// Clear the error message in the file dialog.
  /// This is done outside of the [copyWith] method because
  /// the new [error] could be null.
  FileDialogState clearError() {
    return FileDialogState(
      root: root,
      currentDirectoryId: currentDirectoryId,
      selectedFile: selectedFile,
      isLoading: isLoading,
      filename: filename,
    );
  }
}

// BLoC for the fle dialog
class FileDialogBloc extends Bloc<FileDialogEvent, FileDialogState> {
  /// Subscription to the websocket.
  late StreamSubscription _subscription;

  FileDialogBloc() : super(FileDialogState.initial()) {
    /// Listen for messages from the websocket.
    _subscription = WebSocketManager().messages.listen((message) {
      add(FileDialogReceiveMessageEvent(message));
    });
    on<FileDialogReceiveMessageEvent>(_onReceiveMessage);

    on<UpdateFilenameEvent>((UpdateFilenameEvent event, Emitter<FileDialogState> emit) {
      String filename = event.filename;
      DirectoryElement directory = state.root.getElementById(state.currentDirectoryId) as DirectoryElement;
      FileElement? file = state.root.getChildByName(directory.id, filename);
      FileElement? selectedFile = state.selectedFile;
      if (file != null) {
        selectedFile = file;
      }
      emit(state.copyWith(filename: event.filename, selectedFile: selectedFile));
    });

    on<SelectFileEvent>((SelectFileEvent event, Emitter<FileDialogState> emit) {
      _selectFile(event.fileId, emit);
    });

    on<ToggleExpandDirectoryEvent>((ToggleExpandDirectoryEvent event, Emitter<FileDialogState> emit) {
      FileElement? parentElement = state.root.getElementByPath(event.path);

      if (parentElement is DirectoryElement) {
        parentElement = parentElement.copyWith(isExpanded: !parentElement.isExpanded);
        RootDirectory updatedRoot = state.root.updateElement(parentElement);
        FileDialogState newState = state.copyWith(root: updatedRoot);
        newState = newState.clearSelectedFile();
        emit(newState);
        if (parentElement.isExpanded && !parentElement.isLoaded) {
          add(LoadDirectoryEvent(event.path));
        }
      }
    });

    on<SelectDirectoryEvent>((SelectDirectoryEvent event, Emitter<FileDialogState> emit) {
      FileElement? selectedElement = state.root.getElementByPath(event.path);

      if (selectedElement is DirectoryElement) {
        emit(state.copyWith(currentDirectoryId: selectedElement.id, selectedFile: null, filename: null));
        if (!selectedElement.isLoaded) {
          add(LoadDirectoryEvent(event.path));
        }
      }
    });

    on<LoadDirectoryEvent>((LoadDirectoryEvent event, Emitter<FileDialogState> emit) {
      FileElement? parentElement = state.root.getElementByPath(event.path);

      if (parentElement is DirectoryElement && !parentElement.isLoaded) {
        emit(state.copyWith(isLoading: true));
        WebSocketManager().sendMessage(LoadDirectoryCommand(path: event.path).toJson());
      }
    });
    on<CreateDirectoryEvent>((CreateDirectoryEvent event, Emitter<FileDialogState> emit) {
      WebSocketManager().sendMessage(CreateDirectoryCommand(path: event.path, name: event.name).toJson());
    });
    on<RenameFileEvent>((RenameFileEvent event, Emitter<FileDialogState> emit) {
      WebSocketManager().sendMessage(RenameFileCommand(path: event.path, newName: event.newName).toJson());
    });
    on<DeleteFileEvent>((DeleteFileEvent event, Emitter<FileDialogState> emit) {
      WebSocketManager().sendMessage(DeleteFileCommand(path: event.path).toJson());
    });
    on<DuplicateFileEvent>((DuplicateFileEvent event, Emitter<FileDialogState> emit) {
      WebSocketManager().sendMessage(DuplicateFileCommand(path: event.path).toJson());
    });
    on<MoveFileEvent>((MoveFileEvent event, Emitter<FileDialogState> emit) {
      WebSocketManager().sendMessage(
          MoveFileCommand(sourcePath: event.sourcePath, destinationPath: event.destinationPath).toJson());
    });
    on<SaveFileEvent>((SaveFileEvent event, Emitter<FileDialogState> emit) {
      WebSocketManager().sendMessage(SaveFileCommand(path: event.path, content: event.content).toJson());
    });
    on<LoadFileEvent>((LoadFileEvent event, Emitter<FileDialogState> emit) {
      emit(state.copyWith(isLoading: true));
      WebSocketManager().sendMessage(LoadFileCommand(path: event.path).toJson());
    });
  }

  /// Select a file in the file dialog.
  void _selectFile(String fileId, Emitter<FileDialogState> emit) {
    FileElement? selectedElement = state.root.getElementById(fileId);
    if (selectedElement != null) {
      emit(state.copyWith(selectedFile: selectedElement, filename: selectedElement.name));
    }
  }

  /// Handle messages received from the websocket.
  /// This will update the file dialog state based appropriately so that
  /// it is kep up to date with the remote file system.
  void _onReceiveMessage(FileDialogReceiveMessageEvent event, Emitter<FileDialogState> emit) {
    /// The content of the message.
    final Map<String, dynamic> content = event.message["content"];

    // Only process the file dialog responses
    if (event.message["requestId"] == kFileDialogRequestId) {
      developer.log("message: ${event.message}");
      if (event.message.containsKey("error")) {
        // There was an error in the command
        emit(state.copyWith(error: event.message["error"]));
        reportError(event.message["error"]);
      } else if (event.message["type"] == "directory files") {
        // Update the directory contents
        List<String> path = safeCastList<String>(content["path"]);
        FileElement? parentElement;
        if (path.isNotEmpty && path.first != "") {
          parentElement = state.root.getElementByPath(path);
        } else {
          parentElement = state.root.root;
        }
        if (parentElement is DirectoryElement) {
          RootDirectory updatedRoot = state.root.updateDirectoryContents(
            parentElement.id,
            safeCastList<String>(content["files"]),
            safeCastList<String>(content["directories"]),
          );
          emit(state.copyWith(root: updatedRoot, isLoading: false));
        }
      } else if (event.message["type"] == "file saved") {
        // Notify the user that the file was saved successfully
        _notifyUser(event.message["type"]);
      } else if (event.message["type"] == "directory created") {
        // Create a new directory in the appropriate location
        _notifyUser(event.message["type"]);
        String newId = const Uuid().v4();
        DirectoryElement parent =
            state.root.getElementByPath(safeCastList<String>(event.message["content"]["parent_path"]))
                as DirectoryElement;
        DirectoryElement newDir =
            DirectoryElement(id: newId, name: event.message["content"]["name"], childrenIds: []);
        RootDirectory updatedRoot = state.root.addChild(parent.id, newDir);
        emit(state.copyWith(root: updatedRoot));
      } else if (event.message["type"] == "file loaded") {
        // Mark the file as loaded
        String content = event.message["content"];
        emit(state.copyWith(isLoading: false, filename: content));
      } else if (event.message["type"] == "file renamed") {
        // Update the file tree after renaming
        _notifyUser(event.message["type"]);
        String newName = event.message["content"]["new_name"];
        FileElement? file =
            state.root.getElementByPath(safeCastList<String>(event.message["content"]["path"]));
        if (file != null) {
          RootDirectory updatedRoot = state.root.updateElement(file.copyWith(name: newName));
          emit(state.copyWith(root: updatedRoot));
        } else {
          reportError("Error updating file tree after renaming");
        }
      } else if (event.message["type"] == "file deleted") {
        // Update the file tree after deletion
        _notifyUser(event.message["type"]);
        FileElement? element =
            state.root.getElementByPath(safeCastList<String>(event.message["content"]["deleted_path"]));
        if (element != null) {
          RootDirectory updatedRoot = state.root.removeElement(element.id);

          if (element is DirectoryElement) {
            for (String childId in element.childrenIds) {
              updatedRoot = updatedRoot.removeElement(childId);
            }
          }

          emit(state.copyWith(root: updatedRoot, currentDirectoryId: state.root.rootId));
        } else {
          reportError("Error updating file tree after deletion");
        }
      } else if (event.message["type"] == "file duplicated") {
        // Update the file tree after duplication
        _notifyUser(event.message["type"]);
        String newId = const Uuid().v4();
        List<String> path = safeCastList<String>(event.message["content"]["path"]);
        DirectoryElement parent = state.root.getElementByPath(path) as DirectoryElement;
        path.add(event.message["content"]["old_name"]);

        FileElement? file = state.root.getElementByPath(path);
        if (file != null) {
          FileElement newFile = file.copyWith(id: newId, name: event.message["content"]["new_filename"]);
          RootDirectory updatedRoot = state.root.addChild(parent.id, newFile);
          emit(state.copyWith(root: updatedRoot));
        } else {
          reportError("Error updating file tree after duplication");
        }
      } else if (event.message["type"] == "file moved") {
        // Update the file tree after moving
        _notifyUser(event.message["type"]);
        List<String> sourcePath = safeCastList<String>(event.message["content"]["source_path"]);
        List<String> destinationPath = safeCastList<String>(event.message["content"]["destination_path"]);
        FileElement? file = state.root.getElementByPath(sourcePath);
        DirectoryElement parent = state.root.getElementByPath(destinationPath) as DirectoryElement;
        if (file != null) {
          RootDirectory updatedRoot = state.root.removeElement(file.id);
          updatedRoot = updatedRoot.addChild(parent.id, file);
          emit(state.copyWith(root: updatedRoot));
        } else {
          reportError("Error updating file tree after moving");
        }
      }
    }
  }

  // Display a toast notification to the user.
  void _notifyUser(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      timeInSecForIosWeb: 5,
      fontSize: 16.0,
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
