import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

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

  const SchemaField({
    required this.name,
    required this.type,
    this.unit,
    this.description,
  });

  /// Return the [SchemaField] label to be shown (for example as a [PlotAxis] label.
  String get asLabel => unit == null ? name : "$name ($unit)";

  @override
  String toString() => "SchemaField<$unit>($name, $unit)";
}

typedef ExtremaCallback<T> = bool Function(T lhs, T rhs);

class Schema {
  final String indexColumn;
  final Map<String, SchemaField> fields;
  //Map<String, dynamic> bounds;
  const Schema({required this.indexColumn, required this.fields});
}

class DatabaseTable {
  String name;
  Schema schema;

  DatabaseTable({
    required this.name,
    required this.schema,
  });
}

class Database {
  final int id;
  final String name;
  final String description;
  final List<DatabaseTable> tables;

  Database({
    int? id,
    required this.name,
    required this.tables,
    required this.description,
  }) : id = id ?? _nextDataset++;

  @override
  String toString() => "Database<$name>";
}

class DataCenterUpdate {}

class DataCenter {
  final Map<String, Database> _databases = {};

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
      List<DatabaseTable> tables = [];
      for (Map<String, dynamic> table_dict in schema_dict["tables"]) {
        List<SchemaField> fields = [];
        for (Map<String, dynamic> column in table_dict["columns"]) {
          fields.add(
            SchemaField(
                name: column["name"]!,
                type: DataType.fromString(column["datatype"]!),
                unit: column["unit"],
                description: column["description"]),
          );
        }
        Schema schema = Schema(
            indexColumn: table_dict["index_column"],
            fields: Map.fromIterable(fields, key: (e) => e.name));
        tables.add(DatabaseTable(name: table_dict["name"], schema: schema));
      }

      Database database = Database(
          name: schema_dict["name"],
          description: schema_dict["description"],
          tables: tables);
      databases[database.name] = database;
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

  /// Check if two [SchemaField]s are compatible
  bool isFieldCompatible(SchemaField field1, SchemaField field2) =>
      throw UnimplementedError();

  @override
  String toString() => "DataCenter:[${databases.keys}]";
}
