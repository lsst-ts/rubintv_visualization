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

import 'package:uuid/uuid.dart';

/// An abstract class representing a file system element.
abstract class FileElement {
  /// The unique identifier of the file system element.
  final String id;

  /// The name of the file system element.
  final String name;

  const FileElement({required this.id, required this.name});

  FileElement copyWith({String? id, String? name});
}

/// A class representing a directory in the file system.
class DirectoryElement extends FileElement {
  /// The list of unique identifiers of the children of the directory.
  final List<String> childrenIds;

  /// A flag indicating whether the directory contents (ie. files and sub directories) have been loaded.
  final bool isLoaded;

  /// A flag indicating whether the directory is expanded in the UI.
  final bool isExpanded;

  const DirectoryElement({
    required super.id,
    required super.name,
    required this.childrenIds,
    this.isLoaded = false,
    this.isExpanded = false,
  });

  @override
  DirectoryElement copyWith({
    String? id,
    String? name,
    List<String>? childrenIds,
    bool? isLoaded,
    bool? isExpanded,
  }) {
    return DirectoryElement(
      id: id ?? this.id,
      name: name ?? this.name,
      childrenIds: childrenIds ?? this.childrenIds,
      isLoaded: isLoaded ?? this.isLoaded,
      isExpanded: isExpanded ?? this.isExpanded,
    );
  }

  @override
  String toString() {
    return 'DirectoryElement{id: $id, name: $name, childrenIds: $childrenIds, '
        'isLoaded: $isLoaded, isExpanded: $isExpanded}';
  }
}

/// A class representing a file in the file system.
class FileItem extends FileElement {
  const FileItem({
    required super.id,
    required super.name,
  });

  @override
  FileItem copyWith({String? id, String? name}) {
    return FileItem(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  String toString() => 'FileItem{id: $id, name: $name}';
}

/// A class representing the root directory of the file system.
/// This acts as the so-called "Dungeon Master" of the file system,
/// keeping track of all the immutable file system elements and their relationships.
class RootDirectory {
  /// A map of unique identifiers to file system elements.
  final Map<String, FileElement> elements;

  /// The unique identifier of the root directory.
  final String rootId;

  const RootDirectory({required this.elements, required this.rootId});

  /// A factory constructor to create an empty root directory.
  factory RootDirectory.empty() {
    final rootId = const Uuid().v4();
    return RootDirectory(
      elements: {
        rootId: DirectoryElement(
          id: rootId,
          name: '',
          childrenIds: [],
          isExpanded: true,
        ),
      },
      rootId: rootId,
    );
  }

  RootDirectory copyWith({Map<String, FileElement>? elements}) {
    return RootDirectory(
      elements: elements ?? this.elements,
      rootId: rootId,
    );
  }

  /// The [DirectoryElement] representing the root directory.
  DirectoryElement get root => elements[rootId] as DirectoryElement;

  /// Extract a [FileElement] by its unique [FileElement.id].
  FileElement? getElementById(String id) => elements[id];

  /// Extract a [FileElement] by its unique [FileElement.name] within its parent directory.
  FileElement? getChildByName(String parentId, String name) {
    final DirectoryElement? parent = elements[parentId] as DirectoryElement?;
    if (parent != null) {
      try {
        final String childId = parent.childrenIds.firstWhere(
          (id) => elements[id]?.name == name,
        );
        return elements[childId];
      } on StateError {
        // No element found
        return null;
      }
    }
    return null;
  }

  /// Get the children of a directory by its unique [FileElement.id].
  List<FileElement> getChildrenOfDirectory(String directoryId) {
    final FileElement? directory = elements[directoryId];
    if (directory is DirectoryElement) {
      return directory.childrenIds.map((id) => elements[id]!).toList();
    }
    return [];
  }

  /// Get the names of the children of a directory by its unique [FileElement.id].
  List<String> getChildrenNames(String directoryId) {
    final FileElement? directory = elements[directoryId];
    if (directory is DirectoryElement) {
      return directory.childrenIds.map((id) => elements[id]!.name).toList();
    }
    return [];
  }

  /// Update a [FileElement] in the root directory.
  RootDirectory updateElement(FileElement updatedElement) {
    Map<String, FileElement> newElements = Map.from(elements);
    newElements[updatedElement.id] = updatedElement;
    return RootDirectory(elements: newElements, rootId: rootId);
  }

  /// Add a [FileElement] to the directory tree by specifying the unique id of its parent.
  RootDirectory addChild(String parentId, FileElement child) {
    Map<String, FileElement> newElements = Map.from(elements);
    DirectoryElement? parent = newElements[parentId] as DirectoryElement?;
    if (parent != null && !parent.childrenIds.contains(child.id)) {
      newElements[parentId] = parent.copyWith(
        childrenIds: [...parent.childrenIds, child.id],
      );
      newElements[child.id] = child;
    }
    return RootDirectory(elements: newElements, rootId: rootId);
  }

  /// Remove a [FileElement] from the directory tree by its unique id.
  RootDirectory removeElement(String id) {
    Map<String, FileElement> newElements = Map.from(elements);
    newElements.remove(id);
    newElements.forEach((key, element) {
      if (element is DirectoryElement) {
        if (element.childrenIds.contains(id)) {
          newElements[key] = element.copyWith(
            childrenIds: element.childrenIds.where((childId) => childId != id).toList(),
          );
        }
      }
    });
    return RootDirectory(elements: newElements, rootId: rootId);
  }

  /// Given a list of strings representing a path, return the [FileElement] at that path.
  FileElement? getElementByPath(List<String> path) {
    String currentId = rootId;
    for (String name in path) {
      DirectoryElement? currentDir = elements[currentId] as DirectoryElement?;
      if (currentDir == null) return null;
      String? childId = currentDir.childrenIds.firstWhere(
        (id) => elements[id]?.name == name,
        orElse: () => '',
      );
      if (childId.isEmpty) return null;
      currentId = childId;
    }
    return elements[currentId];
  }

  /// Given the unique ID of a [FileElement], extract the path to that element in the file system.
  List<String> getPathById(String id) {
    List<String> path = [];
    String? currentId = id;
    while (currentId != null && currentId != rootId) {
      FileElement? element = elements[currentId];
      if (element != null) {
        path.insert(0, element.name);
        currentId = elements.entries
            .firstWhere(
              (entry) =>
                  entry.value is DirectoryElement &&
                  (entry.value as DirectoryElement).childrenIds.contains(currentId),
              orElse: () => MapEntry(rootId, elements[rootId]!),
            )
            .key;
      } else {
        throw Exception('Element with id $currentId not found');
      }
    }
    return path;
  }

  /// Update the contents of a directory by its unique id.
  RootDirectory updateDirectoryContents(String directoryId, List<String> files, List<String> directories) {
    final DirectoryElement? directory = elements[directoryId] as DirectoryElement?;
    if (directory != null) {
      Map<String, FileElement> newElements = Map.from(elements);
      for (String fileId in directory.childrenIds) {
        newElements.remove(fileId);
      }
      List<String> newChildIds = [];
      for (String dirName in directories) {
        String fileId = const Uuid().v4();
        newChildIds.add(fileId);
        newElements[fileId] = DirectoryElement(id: fileId, name: dirName, childrenIds: []);
      }
      for (String fileName in files) {
        String fileId = const Uuid().v4();
        newChildIds.add(fileId);
        newElements[fileId] = FileItem(id: fileId, name: fileName);
      }
      newElements[directoryId] = directory.copyWith(
        childrenIds: newChildIds,
        isLoaded: true,
      );
      return RootDirectory(elements: newElements, rootId: rootId);
    }
    return this;
  }

  /// Convert the file system tree to a string representation.
  String _elementToString(String elementId, int indentLevel, {bool isLast = false}) {
    final element = elements[elementId];
    if (element == null) return '';

    final indent = '    ' * (indentLevel - 1);
    final String name = element.id == rootId ? "Root" : element.name;
    final prefix = indentLevel == 0 ? '' : (isLast ? '└── ' : '├── ');
    String result = '$indent$prefix$name\n';

    if (element is DirectoryElement) {
      final childrenCount = element.childrenIds.length;
      for (var i = 0; i < childrenCount; i++) {
        final childId = element.childrenIds[i];
        final isLastChild = i == childrenCount - 1;

        if (!isLast) {
          result += '$indent│   \n';
        } else {
          result += '$indent    \n';
        }

        result += _elementToString(childId, indentLevel + 1, isLast: isLastChild);
      }
    }

    return result;
  }

  /// Get the full string representation of the file system tree.
  String get fullString => _elementToString(rootId, 0);
}
