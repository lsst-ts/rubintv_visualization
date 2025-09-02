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

import 'dart:convert';

import 'package:rubintv_visualization/dialog/base.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/primitives.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/chart/series.dart';

/// A command to be sent to the analysis service via websockets.
class ServiceCommand {
  /// The name of the command
  String name;

  /// The request ID of the command.
  dynamic requestId;

  /// The parameters of the command.
  Map<String, dynamic> parameters;

  ServiceCommand({
    required this.name,
    required this.parameters,
    this.requestId,
  });

  /// Convert the command to a JSON formatted string.
  String toJson() {
    if (requestId != null) {
      return jsonEncode({
        "name": name,
        "parameters": parameters,
        "requestId": requestId,
      });
    }
    return jsonEncode({"name": name, "parameters": parameters});
  }
}

/// A command to load a new instrument.
class LoadInstrumentAction extends ServiceCommand {
  LoadInstrumentAction({required String instrument})
      : super(
          name: "load instrument",
          parameters: {
            "instrument": instrument,
          },
        );
}

/// A command to load a new series.
class FutureLoadColumnsCommand extends ServiceCommand {
  FutureLoadColumnsCommand({required List<SchemaField> fields, required String seriesId})
      : super(
          name: "load columns",
          requestId: seriesId,
          parameters: {
            "fields": fields.map((e) => "${e.database.name}.${e.schema.name}.${e.name}").toList(),
          },
        );
}

/// A command to load a new series.
class LoadColumnsCommand extends ServiceCommand {
  LoadColumnsCommand({
    required UniqueId windowId,
    required SeriesId seriesId,
    required String database,
    required List<String> columns,
    Set<DataId>? dataIds,
    QueryExpression? query,
    QueryExpression? globalQuery,
    String? dayObs,
    bool? isNewPlot,
  }) : super(
          name: "load columns",
          requestId: "${windowId.id},${seriesId.shortString}",
          parameters: {
            "database": database,
            "columns": columns,
            "query": query?.toCommand(),
            "global_query": globalQuery?.toCommand(),
            "data_ids": dataIds?.map((e) => [e.dayObs, e.seqNum]).toList(),
            "day_obs": dayObs,
            "is_new_plot": isNewPlot,
          },
        );

  /// Build a new [LoadColumnsCommand] from the given parameters.
  static LoadColumnsCommand build({
    required List<SchemaField> fields,
    required UniqueId windowId,
    required SeriesId seriesId,
    required bool useGlobalQuery,
    QueryExpression? query,
    QueryExpression? globalQuery,
    String? dayObs,
    Set<DataId>? dataIds,
    bool? isNewPlot = false,
  }) {
    return LoadColumnsCommand(
      windowId: windowId,
      seriesId: seriesId,
      database: fields.first.database.name,
      columns: fields.map((e) => "${e.schema.name}.${e.name}").toList(),
      query: query,
      globalQuery: useGlobalQuery ? globalQuery : null,
      dayObs: dayObs,
      dataIds: dataIds,
      isNewPlot: isNewPlot,
    );
  }
}

/// A command to load a new series.
class CountRowsCommand extends ServiceCommand {
  CountRowsCommand({
    required UniqueId windowId,
    required SeriesId seriesId,
    required String database,
    required List<String> columns,
    Set<DataId>? dataIds,
    QueryExpression? query,
    QueryExpression? globalQuery,
    String? dayObs,
  }) : super(
          name: "load columns",
          requestId: "${windowId.id},${seriesId.shortString}",
          parameters: {
            "aggregator": "count",
            "database": database,
            "columns": columns,
            "query": query?.toCommand(),
            "global_query": globalQuery?.toCommand(),
            "data_ids": dataIds?.map((e) => [e.dayObs, e.seqNum]).toList(),
            "day_obs": dayObs,
            "response_type": "count",
          },
        );

  /// Build a new [CountRowsCommand] from the given parameters.
  static CountRowsCommand build({
    required List<SchemaField> fields,
    required UniqueId windowId,
    required SeriesId seriesId,
    required bool useGlobalQuery,
    QueryExpression? query,
    QueryExpression? globalQuery,
    String? dayObs,
    Set<DataId>? dataIds,
  }) {
    return CountRowsCommand(
      windowId: windowId,
      seriesId: seriesId,
      database: fields.first.database.name,
      columns: fields.map((e) => "${e.schema.name}.${e.name}").toList(),
      query: query,
      globalQuery: useGlobalQuery ? globalQuery : null,
      dayObs: dayObs,
      dataIds: dataIds,
    );
  }
}

/// RequestID for commands sent from the file dialog.
const String kFileDialogRequestId = "file dialog";

/// A command sent by the file dialog.
class FileDialogCommand extends ServiceCommand {
  FileDialogCommand({required super.name, required super.parameters})
      : super(requestId: kFileDialogRequestId);
}

/// Load the contents of a directory.
class LoadDirectoryCommand extends FileDialogCommand {
  LoadDirectoryCommand({required List<String> path})
      : super(
          name: "list directory",
          parameters: {
            "path": path,
          },
        );
}

/// Create a new directory.
class CreateDirectoryCommand extends FileDialogCommand {
  CreateDirectoryCommand({required List<String> path, required String name})
      : super(
          name: "create directory",
          parameters: {
            "path": path,
            "name": name,
          },
        );
}

/// Rename a file.
class RenameFileCommand extends FileDialogCommand {
  RenameFileCommand({required List<String> path, required String newName})
      : super(
          name: "rename",
          parameters: {
            "path": path,
            "new_name": newName,
          },
        );
}

/// Delete a file.
class DeleteFileCommand extends FileDialogCommand {
  DeleteFileCommand({required List<String> path})
      : super(
          name: "delete",
          parameters: {
            "path": path,
          },
        );
}

/// Duplicate a file.
class DuplicateFileCommand extends FileDialogCommand {
  DuplicateFileCommand({required List<String> path})
      : super(
          name: "duplicate",
          parameters: {
            "path": path,
          },
        );
}

/// Move a file.
class MoveFileCommand extends FileDialogCommand {
  MoveFileCommand({required List<String> sourcePath, required List<String> destinationPath})
      : super(
          name: "move",
          parameters: {
            "source_path": sourcePath,
            "destination_path": destinationPath,
          },
        );
}

/// Save the contents of a file.
class SaveFileCommand extends FileDialogCommand {
  SaveFileCommand({required List<String> path, required String content})
      : super(
          name: "save",
          parameters: {
            "path": path,
            "content": content,
          },
        );
}

/// Load the contents of a file.
class LoadFileCommand extends FileDialogCommand {
  LoadFileCommand({required List<String> path})
      : super(
          name: "load",
          parameters: {
            "path": path,
          },
        );
}

/// A persisted workspace file on a file system
class WorkspaceFile extends FileElement {
  /// The JSON string to create the workspace.
  final String contents;

  WorkspaceFile({
    required super.id,
    required super.name,
    required this.contents,
  });

  @override
  WorkspaceFile copyWith({
    String? id,
    String? name,
    String? contents,
  }) {
    return WorkspaceFile(
      id: id ?? this.id,
      name: name ?? this.name,
      contents: contents ?? this.contents,
    );
  }
}
