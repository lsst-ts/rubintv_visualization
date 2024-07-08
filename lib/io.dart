import 'dart:convert';

import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/chart/series.dart';

/// A command to be sent to the analysis service.
class ServiceCommand {
  /// The name of the command
  String name;

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

class LoadInstrumentAction extends ServiceCommand {
  LoadInstrumentAction({required String instrument})
      : super(
          name: "load instrument",
          parameters: {
            "instrument": instrument,
          },
        );
}

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

class LoadColumnsCommand extends ServiceCommand {
  LoadColumnsCommand({
    required UniqueId windowId,
    required SeriesId seriesId,
    required String database,
    required List<String> columns,
    Set<DataId>? dataIds,
    Query? query,
    Query? globalQuery,
    String? dayObs,
  }) : super(
          name: "load columns",
          requestId: "${windowId.id},${seriesId.shortString}",
          parameters: {
            "database": database,
            "columns": columns,
            "query": query?.toDict(),
            "global_query": globalQuery?.toDict(),
            "data_ids": dataIds?.map((e) => [e.dayObs, e.seqNum]).toList(),
            "day_obs": dayObs,
          },
        );

  static LoadColumnsCommand build({
    required List<SchemaField> fields,
    required UniqueId windowId,
    required SeriesId seriesId,
    required bool useGlobalQuery,
    Query? query,
    Query? globalQuery,
    String? dayObs,
    Set<DataId>? dataIds,
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
    );
  }
}
