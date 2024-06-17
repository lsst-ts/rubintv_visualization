import 'dart:convert';

import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/series.dart';

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
    required List<SchemaField> fields,
    required UniqueId windowId,
    required SeriesId seriesId,
    Query? query,
  }) : super(
          name: "load columns",
          requestId: "${windowId.id},${seriesId.shortString}",
          parameters: {
            "database": fields.first.database.name,
            "columns": fields.map((e) => "${e.schema.name}.${e.name}").toList(),
            "query": query?.toDict(),
          },
        );
  static LoadColumnsCommand build({
    required List<SchemaField> fields,
    required UniqueId windowId,
    required SeriesId seriesId,
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
          field: SchemaField(name: "obsNight", dataType: ColumnDataType.dateTime),
          rightValue: obsDate,
          rightOperator: EqualityOperator.eq);
      if (fullQuery == null) {
        fullQuery = obsQuery;
      } else {
        fullQuery = fullQuery & obsQuery;
      }
    }
    return LoadColumnsCommand(
      fields: fields,
      windowId: windowId,
      seriesId: seriesId,
      query: fullQuery,
    );
  }
}
