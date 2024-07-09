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
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/chart/series.dart';

/// Unique ID of the next dataset
int _nextDataset = 0;

/// Names of tables with exposure data
const List<String> kExposureTables = [
  "exposure",
  "ccdexposure",
  "ccdexposure_camera",
];

/// Names of tables with single visit exposure data
const List<String> kVisit1Tables = [
  "visit1",
  "visit1_quicklook",
  "ccdvisit1",
  "ccdvisit1_quicklook",
];

/// Names of tables with CCD data
const List<String> kCcdTables = [
  "ccdexposure",
  "ccdexposure_camera",
  "ccdvisit1",
  "ccdvisit1_quicklook",
];

/// An exception thrown when there is an issue with data access.
class DataAccessException implements IOException {
  DataAccessException(this.message);

  /// The message associated with the exception.
  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

/// Convert a string into a [ColumnDataType].
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

/// Convert a [ColumnDataType] into a [Type].
const Map<ColumnDataType, Type> _dataTypeToType = {
  ColumnDataType.string: String,
  ColumnDataType.number: double,
  ColumnDataType.dateTime: DateTime,
};

/// A field in a database table.
class SchemaField {
  /// The name of the field.
  final String name;

  /// The data type of the field.
  final ColumnDataType dataType;

  /// The unit of the field.
  final String? unit;

  /// The description of the field.
  final String? description;

  /// The schema that contains the [SchemaField].
  late final TableSchema schema;

  /// The bounds of the field.
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

  /// The [Type] of the field.
  Type get type => _dataTypeToType[dataType]!;
}

/// A table schema.
class TableSchema {
  /// The name of the table.
  final String name;

  /// The name of the primary key of the table.
  final String indexKey;

  /// The fields in the table.
  final Map<String, SchemaField> fields;

  /// The database that contains the [TableSchema].
  late final DatabaseSchema database;

  TableSchema({required this.name, required this.indexKey, required this.fields}) {
    for (SchemaField field in fields.values) {
      field.schema = this;
    }
  }
}

/// A data source.
/// For example this could be a database, a Butler instance, or an EFD client.
abstract class DataSource {
  /// The unique ID of the [DataSource].
  final int id;

  /// The name of the [DataSource].
  final String name;

  /// The description of the [DataSource].
  final String description;

  DataSource({
    int? id,
    required this.name,
    required this.description,
  }) : id = id ?? _nextDataset++;
}

/// A database schema.
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

/// A Butler instance.
class Butler extends DataSource {
  /// Repo of the Butler
  final String repo;

  /// Collections to load data from
  final List<String> collections;

  Butler({
    super.id,
    required super.name,
    required super.description,
    required this.repo,
    required this.collections,
  });
}

/// An EFD client.
class EfdClient extends DataSource {
  /// Connection string of the EFD client
  final String connectionString;

  EfdClient({
    super.id,
    required super.name,
    required super.description,
    required this.connectionString,
  });
}

/// A data center that contains all of the data for the workspace,
/// allowing the individual widgets to have immutable states with low memory usage.
class DataCenter {
  /// Make the [DataCenter] a singleton.
  static final DataCenter _singleton = DataCenter._internal();

  /// The [DataCenter] factory constructor.
  factory DataCenter() => _singleton;

  /// The private [DataCenter] constructor.
  DataCenter._internal();

  /// The [StreamSubscription] to listen for messages from the [WebSocketManager].
  late StreamSubscription _subscription;

  /// The databases in the [DataCenter].
  final Map<String, DatabaseSchema> _databaseSchemas = {};

  /// The butlers in the [DataCenter].
  final Map<String, Butler> butlers = {};

  /// The EFD client.
  EfdClient? efdClient;

  /// Data for all of the series in the [DataCenter].
  final Map<SeriesId, SeriesData> _seriesData = {};

  /// Subscribe to the [WebSocketManager] messages.
  void initialize() {
    _subscription = WebSocketManager().messages.listen((Map<String, dynamic> message) {
      developer.log("DataCenter received message: ${message['type']}", name: "rubinTV.workspace.data");
      if (message['type'] == 'instrument info' && message['content'].containsKey('schema')) {
        addDatabaseSchema(message['content']['schema']);
      }
    });
  }

  /// Get the map of databases.
  Map<String, DatabaseSchema> get databases => {..._databaseSchemas};

  /// Get data for a series with the given [SeriesId].
  SeriesData? getSeriesData(SeriesId id) => _seriesData[id];

  /// Get the set of series IDs.
  Set<SeriesId> get seriesIds => _seriesData.keys.toSet();

  /// Add a new database schema to the [DataCenter].
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
      // Add the tables to the database schema
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

      // Create the DatabaseSchema
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

  /// Update the data for a series.
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

  void dispose() {
    _subscription.cancel();
  }
}

/// DataId for an entry in the exposure or visit table
class DataId {
  /// The sequence number of the data point.
  final int seqNum;

  /// The observation day of the data point.
  final int dayObs;

  const DataId({required this.seqNum, required this.dayObs});

  @override
  bool operator ==(Object other) => other is DataId && other.seqNum == seqNum && other.dayObs == dayObs;

  @override
  int get hashCode => seqNum.hashCode ^ dayObs.hashCode;

  /// Convert the [DataId] to a JSON string.
  String toJson() => jsonEncode({"seq_num": seqNum, "day_obs": dayObs});

  /// Create a [DataId] from a JSON string.
  @override
  String toString() => "DataId($seqNum, $dayObs)";
}
