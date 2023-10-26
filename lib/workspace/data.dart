import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/utils.dart';

int _nextDataset = 0;

class DataAccessException implements IOException {
  DataAccessException(this.message);

  String? message;

  @override
  String toString() => "$runtimeType:\n\t$message";
}

enum DataType {
  string,
  integer,
  double,
  dateTime;

  static DataType fromString(String dataType) {
    switch (dataType) {
      case "char":
        return DataType.string;
      case "int":
        return DataType.integer;
      case "long":
        return DataType.integer;
      case "float":
        return DataType.double;
      case "double":
        return DataType.double;
      case "timestamp":
        return DataType.dateTime;
      default:
        throw DataAccessException("Unknown data type: $dataType");
    }
  }
}

Map<Type, DataType> _dataTypeLookup = {
  String: DataType.string,
  int: DataType.integer,
  double: DataType.double,
  DateTime: DataType.dateTime,
};

class SchemaField {
  final String name;
  final DataType? type;
  final String? unit;
  final String? description;
  late final Schema schema;
  final Bounds? bounds;

  SchemaField({
    required this.name,
    required this.type,
    this.unit,
    this.description,
    this.bounds,
  });

  /// Get the database that contains the [SchemaField].
  Database get database => schema.database;

  /// Return the [SchemaField] label to be shown (for example as a [PlotAxis] label.
  String get asLabel => unit == null ? name : "$name ($unit)";

  @override
  String toString() => "SchemaField<$unit>($name, $unit)";

  /// Whether or not the field is a string.
  bool get isString => type == DataType.string;

  /// Whether or not the field is a number.
  bool get isNumerical => type == DataType.integer || type == DataType.double;

  /// Whether or not the field is a date/time.
  bool get isDateTime => type == DataType.dateTime;
}

typedef ExtremaCallback<T> = bool Function(T lhs, T rhs);

class Schema {
  final String name;
  final String indexColumn;
  final Map<String, SchemaField> fields;
  late final Database database;

  Schema(
      {required this.name, required this.indexColumn, required this.fields}) {
    for (SchemaField field in fields.values) {
      field.schema = this;
    }
  }
}

class Database {
  final int id;
  final String name;
  final String description;
  final Map<String, Schema> tables;

  Database({
    int? id,
    required this.name,
    required this.tables,
    required this.description,
  }) : id = id ?? _nextDataset++ {
    for (Schema schema in tables.values) {
      schema.database = this;
    }
  }

  @override
  String toString() => "Database<$name>";
}

class DataCenterUpdate {}

class DataCenter {
  final Map<String, Database> _databases = {};
  final Map<UniqueId, List<Map<String, dynamic>>> _data = {};

  DataCenter();

  Map<String, Database> get databases => {..._databases};

  void addDatabase(Map<String, dynamic> schema_dict) {
    if (!schema_dict.containsKey("name")) {
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
      Map<String, Schema> tables = {};
      for (Map<String, dynamic> tableDict in schema_dict["tables"]) {
        List<SchemaField> fields = [];
        for (Map<String, dynamic> column in tableDict["columns"]) {
          fields.add(
            SchemaField(
                name: column["name"]!,
                type: DataType.fromString(column["datatype"]!),
                unit: column["unit"],
                description: column["description"]),
          );
        }
        Schema schema = Schema(
            name: tableDict["name"],
            indexColumn: tableDict["index_column"],
            fields: Map.fromIterable(fields, key: (e) => e.name));
        tables[tableDict["name"]!] = schema;
      }

      Database database = Database(
          name: schema_dict["name"],
          description: schema_dict["description"],
          tables: tables);
      _databases[database.name] = database;
    } catch (e, s) {
      print("error: $e");
      print(s);
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

  List<Map<String, dynamic>>? getSeriesData(UniqueId id) => _data[id];

  void updateSeriesData({
    required UniqueId seriesId,
    required List<dynamic> columnNames,
    required List<List<dynamic>> data,
  }) {
    List<Map<String, dynamic>> result = [];
    for (List<dynamic> row in data) {
      Map<String, dynamic> rowDict = {};
      for (int i = 0; i < columnNames.length; i++) {
        rowDict[columnNames[i]] = row[i];
      }
      rowDict["series"] = seriesId.id.toString();
      result.add(rowDict);
    }
    _data[seriesId] = result;
  }

  /// Check if two [SchemaField]s are compatible
  bool isFieldCompatible(SchemaField field1, SchemaField field2) =>
      throw UnimplementedError();

  @override
  String toString() => "DataCenter:[${databases.keys}]";

  Map<UniqueId, List<Map<String, dynamic>>> get data => {..._data};
}
