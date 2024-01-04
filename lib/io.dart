import 'dart:convert';

import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// A command to be sent to the analysis service.
class ServiceCommand {
  /// The name of hte command
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

class LoadSchemaCommand extends ServiceCommand {
  LoadSchemaCommand()
      : super(
          name: "load schema",
          parameters: {
            "database": "summitcdb",
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
    required List<SchemaField> fields,
    required UniqueId seriesId,
    Query? query,
  }) : super(
          name: "load columns",
          requestId: "${seriesId.id}",
          parameters: {
            "database": fields.first.database.name,
            "columns": fields.map((e) => "${e.schema.name}.${e.name}").toList(),
            "query": query?.toDict(),
          },
        );
  static LoadColumnsCommand build({
    required List<SchemaField> fields,
    required UniqueId seriesId,
    required bool useGlobalQuery,
    required Query? query,
    required Query? globalQuery,
    required String? obsDate,
  }) {
    Query? fullQuery = query;
    if (useGlobalQuery && globalQuery != null) {
      if (fullQuery == null) {
        fullQuery = globalQuery;
      } else {
        fullQuery = fullQuery & globalQuery;
      }
    }
    if (obsDate != null) {
      Query obsQuery = EqualityQuery(
          id: UniqueId.next(),
          field: SchemaField(name: "obsNight", type: DataType.dateTime),
          rightValue: obsDate,
          rightOperator: EqualityOperator.eq);
      if (fullQuery == null) {
        fullQuery = obsQuery;
      } else {
        fullQuery = fullQuery & obsQuery;
      }
    }
    return LoadColumnsCommand(fields: fields, seriesId: seriesId, query: fullQuery);
  }
}
