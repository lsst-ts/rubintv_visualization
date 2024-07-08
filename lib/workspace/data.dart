import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/chart/series.dart';

int _nextDataset = 0;

const List<String> kExposureTables = [
  "exposure",
  "ccdexposure",
  "ccdexposure_camera",
];

const List<String> kVisit1Tables = [
  "visit1",
  "visit1_quicklook",
  "ccdvisit1",
  "ccdvisit1_quicklook",
];

const List<String> kCcdTables = [
  "ccdexposure",
  "ccdexposure_camera",
  "ccdvisit1",
  "ccdvisit1_quicklook",
];

class DataAccessException implements IOException {
  DataAccessException(this.message);

  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

ColumnDataType? dataTypeFromString(String dataType) {
  switch (dataType) {
    case "char":
      return ColumnDataType.string;
    case "string":
      return ColumnDataType.string;
    case "text":
      return ColumnDataType.string;
    case "int":
      return ColumnDataType.number;
    case "long":
      return ColumnDataType.number;
    case "float":
      return ColumnDataType.number;
    case "double":
      return ColumnDataType.number;
    case "timestamp":
      return ColumnDataType.dateTime;
    case "boolean":
      return null;
    default:
      throw DataAccessException("Unknown data type: $dataType");
  }
}

/// Convert dates without a dash into a format that rubin_chart recognizes.
DateTime convertRubinDate(String date) {
  List<String> dateSplit = date.split("-");
  if (dateSplit.length == 1) {
    date = "${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6)}";
  }
  return dateFromString(date);
}

const Map<Type, ColumnDataType> _typeToDataType = {
  String: ColumnDataType.string,
  int: ColumnDataType.number,
  double: ColumnDataType.number,
  DateTime: ColumnDataType.dateTime,
};

const Map<ColumnDataType, Type> _dataTypeToType = {
  ColumnDataType.string: String,
  ColumnDataType.number: double,
  ColumnDataType.dateTime: DateTime,
};

class SchemaField {
  final String name;
  final ColumnDataType dataType;
  final String? unit;
  final String? description;
  late final TableSchema schema;
  final Bounds? bounds;

  SchemaField({
    required this.name,
    required this.dataType,
    this.unit,
    this.description,
    this.bounds,
  });

  /// Get the database that contains the [SchemaField].
  DatabaseSchema get database => schema.database;

  /// Return the [SchemaField] label to be shown (for example as a [PlotAxis] label.
  String get asLabel => unit == null ? name : "$name ($unit)";

  @override
  String toString() => "SchemaField<$unit>($name, $unit)";

  /// Whether or not the field is a string.
  bool get isString => dataType == ColumnDataType.string;

  /// Whether or not the field is a number.
  bool get isNumerical => dataType == ColumnDataType.number;

  /// Whether or not the field is a date/time.
  bool get isDateTime => dataType == ColumnDataType.dateTime;

  Type get type => _dataTypeToType[dataType]!;
}

typedef ExtremaCallback<T> = bool Function(T lhs, T rhs);

class TableSchema {
  final String name;
  final String indexKey;
  final Map<String, SchemaField> fields;
  late final DatabaseSchema database;

  TableSchema({required this.name, required this.indexKey, required this.fields}) {
    for (SchemaField field in fields.values) {
      field.schema = this;
    }
  }
}

abstract class DataSource {
  final int id;
  final String name;
  final String description;

  DataSource({
    int? id,
    required this.name,
    required this.description,
  }) : id = id ?? _nextDataset++;
}

class DatabaseSchema extends DataSource {
  final Map<String, TableSchema> tables;

  DatabaseSchema({
    super.id,
    required super.name,
    required super.description,
    required this.tables,
  }) {
    for (TableSchema schema in tables.values) {
      schema.database = this;
    }
  }

  @override
  String toString() => "Database<$name>";
}

class Butler extends DataSource {
  final String repo;
  final List<String> collections;

  Butler({
    super.id,
    required super.name,
    required super.description,
    required this.repo,
    required this.collections,
  });
}

class EfdClient extends DataSource {
  final String connectionString;

  EfdClient({
    super.id,
    required super.name,
    required super.description,
    required this.connectionString,
  });
}

class DataCenterUpdate {}

class DataCenter {
  /// Make the [DataCenter] a singleton.
  static final DataCenter _singleton = DataCenter._internal();

  /// The [DataCenter] factory constructor.
  factory DataCenter() => _singleton;

  /// The private [DataCenter] constructor.
  DataCenter._internal();

  late StreamSubscription _subscription;
  final Map<String, DatabaseSchema> _databaseSchemas = {};
  final Map<String, Butler> butlers = {};
  EfdClient? efdClient;
  final Map<SeriesId, SeriesData> _seriesData = {};

  void initialize() {
    _subscription = WebSocketManager().messages.listen((Map<String, dynamic> message) {
      developer.log("DataCenter received message: ${message['type']}", name: "rubinTV.workspace.data");
      if (message['type'] == 'instrument info' && message['content'].containsKey('schema')) {
        addDatabaseSchema(message['content']['schema']);
      }
    });
  }

  Map<String, DatabaseSchema> get databases => {..._databaseSchemas};

  SeriesData? getSeriesData(SeriesId id) => _seriesData[id];

  Set<SeriesId> get seriesIds => _seriesData.keys.toSet();

  void addDatabaseSchema(Map<String, dynamic> schemaDict) {
    if (!schemaDict.containsKey("name")) {
      String msg = "Schema does not contain a name";
      Fluttertoast.showToast(
          msg: msg,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 5,
          backgroundColor: Colors.red,
          webBgColor: "#e74c3c",
          textColor: Colors.white,
          fontSize: 16.0);
      return;
    }

    try {
      Map<String, TableSchema> tables = {};
      for (Map<String, dynamic> tableDict in schemaDict["tables"]) {
        List<SchemaField> fields = [];
        if ((tableDict["name"] as String).contains("flexdata")) {
          continue;
        }
        for (Map<String, dynamic> column in tableDict["columns"]) {
          ColumnDataType? dataType = dataTypeFromString(column["datatype"]);
          if (dataType != null) {
            fields.add(
              SchemaField(
                  name: column["name"]!,
                  dataType: dataType,
                  unit: column["unit"],
                  description: column["description"]),
            );
          }
        }
        String indexKey;
        if (kExposureTables.contains(tableDict["name"])) {
          indexKey = "exposure_id";
        } else if (kVisit1Tables.contains(tableDict["name"])) {
          indexKey = "visit_id";
        } else {
          throw DataAccessException("Unknown table: ${tableDict["name"]}");
        }
        TableSchema schema = TableSchema(
          name: tableDict["name"],
          indexKey: indexKey,
          fields: Map.fromIterable(fields, key: (e) => e.name),
        );
        tables[tableDict["name"]!] = schema;
      }

      DatabaseSchema database =
          DatabaseSchema(name: schemaDict["name"], description: schemaDict["description"], tables: tables);
      _databaseSchemas[database.name] = database;
    } catch (e, s) {
      developer.log("error: $e", name: "rubinTV.workspace.data", error: e, stackTrace: s);
      String msg = "Could not initialize database";
      Fluttertoast.showToast(
          msg: msg,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 5,
          backgroundColor: Colors.red,
          webBgColor: "#e74c3c",
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  void updateSeriesData({
    required String dataSourceName,
    required SeriesInfo series,
    required List<String> plotColumns,
    required Map<String, List<dynamic>> data,
  }) {
    int rows = data.values.first.length;
    if (rows == 0) {
      String msg = "No non-null data found for the selected columns.";
      Fluttertoast.showToast(
          msg: msg,
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 5,
          backgroundColor: Colors.red,
          webBgColor: "#e74c3c",
          textColor: Colors.white,
          fontSize: 16.0);
      return;
    }

    DataSource dataSource = _databaseSchemas[dataSourceName]!;

    if (dataSource is DatabaseSchema) {
      Map<SchemaField, List<dynamic>> columns = {};
      Map<AxisId, SchemaField> seriesColumns = {};

      // Add the series data for each column in the plot
      for (int i = 0; i < plotColumns.length; i++) {
        String plotColumn = plotColumns[i];
        List<String> split = plotColumn.split(".");
        String tableName = split[0];
        String columnName = split[1];

        SchemaField field = dataSource.tables[tableName]!.fields[columnName]!;
        if (series.fields.containsValue(field)) {
          if (field.isString) {
            columns[field] = List<String>.from(data[plotColumn]!.map((e) => e));
          } else if (field.isNumerical) {
            columns[field] = List<double>.from(data[plotColumn]!.map((e) => e.toDouble()));
          } else if (field.isDateTime) {
            columns[field] = List<DateTime>.from(data[plotColumn]!.map((e) => convertRubinDate(e)));
          }

          // Add the column to the series columns
          AxisId axisId = series.axes[series.fields.values.toList().indexOf(field)];
          seriesColumns[axisId] = field;
        }
      }
      List<DataId> dataIds = List.generate(
          data['seq_num']!.length, (i) => DataId(seqNum: data['seq_num']![i], dayObs: data['day_obs']![i]));

      SeriesData seriesData = SeriesData.fromData(
        data: columns,
        plotColumns: seriesColumns,
        dataIds: dataIds,
      );

      _seriesData[series.id] = seriesData;
    } else {
      throw DataAccessException("Unknown data source: $dataSource");
    }
  }

  /// Check if two [SchemaField]s are compatible
  bool isFieldCompatible(SchemaField field1, SchemaField field2) => throw UnimplementedError();

  @override
  String toString() => "DataCenter:[${databases.keys}]";

  void removeSeriesData(SeriesId id) {
    _seriesData.remove(id);
  }
}

class DataId {
  final int seqNum;
  final int dayObs;

  const DataId({required this.seqNum, required this.dayObs});

  @override
  bool operator ==(Object other) => other is DataId && other.seqNum == seqNum && other.dayObs == dayObs;

  @override
  int get hashCode => seqNum.hashCode ^ dayObs.hashCode;

  String toJson() => jsonEncode({"seq_num": seqNum, "day_obs": dayObs});

  @override
  String toString() => "DataId($seqNum, $dayObs)";
}
