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

const Map<Type, DataType> _typeToDataType = {
  String: DataType.string,
  int: DataType.integer,
  double: DataType.double,
  DateTime: DataType.dateTime,
};

const Map<DataType, Type> _dataTypeToType = {
  DataType.string: String,
  DataType.integer: int,
  DataType.double: double,
  DataType.dateTime: DateTime,
};

class SchemaField {
  final String name;
  final DataType dataType;
  final String? unit;
  final String? description;
  late final Schema schema;
  final Bounds? bounds;

  SchemaField({
    required this.name,
    required this.dataType,
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
  bool get isString => dataType == DataType.string;

  /// Whether or not the field is a number.
  bool get isNumerical => dataType == DataType.integer || dataType == DataType.double;

  /// Whether or not the field is a date/time.
  bool get isDateTime => dataType == DataType.dateTime;

  Type get type => _dataTypeToType[dataType]!;
}

typedef ExtremaCallback<T> = bool Function(T lhs, T rhs);

class Schema {
  final String name;
  final List<String> indexColumns;
  final Map<String, SchemaField> fields;
  late final Database database;

  Schema({required this.name, required this.indexColumns, required this.fields}) {
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

class Database extends DataSource {
  final Map<String, Schema> tables;

  Database({
    super.id,
    required super.name,
    required super.description,
    required this.tables,
  }) {
    for (Schema schema in tables.values) {
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
  final Map<String, Database> _databases = {};
  final Map<String, Butler> butlers = {};
  EfdClient? efdClient;
  final Map<UniqueId, SeriesData> _data = {};

  DataCenter();

  Map<String, Database> get databases => {..._databases};

  void addDatabase(Map<String, dynamic> schemaDict) {
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
      Map<String, Schema> tables = {};
      for (Map<String, dynamic> tableDict in schemaDict["tables"]) {
        List<SchemaField> fields = [];
        for (Map<String, dynamic> column in tableDict["columns"]) {
          fields.add(
            SchemaField(
                name: column["name"]!,
                dataType: DataType.fromString(column["datatype"]!),
                unit: column["unit"],
                description: column["description"]),
          );
        }
        Schema schema = Schema(
            name: tableDict["name"],
            indexColumns: tableDict["index_columns"].map<String>((e) => e.toString()).toList(),
            fields: Map.fromIterable(fields, key: (e) => e.name));
        tables[tableDict["name"]!] = schema;
      }

      Database database =
          Database(name: schemaDict["name"], description: schemaDict["description"], tables: tables);
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

  SeriesData? getSeriesData(UniqueId id) => _data[id];

  void updateSeriesData({
    required DataSource dataSource,
    required UniqueId seriesId,
    required List<String> plotColumns,
    required Map<String, List<dynamic>> data,
    required List<DataId> dataIds,
  }) {
    if (dataSource is Database) {
      Map<String, List<dynamic>> columns = {};
      for (String plotColumn in plotColumns) {
        List<String> split = plotColumn.split(".");
        String tableName = split[0];
        String columnName = split[1];

        SchemaField field = dataSource.tables[tableName]!.fields[columnName]!;
        if (field.isString) {
          columns[plotColumn] = List<String>.from(data[plotColumn]!.map((e) => e));
        } else if (field.isNumerical) {
          columns[plotColumn] = List<double>.from(data[plotColumn]!.map((e) => e));
        } else if (field.isDateTime) {
          columns[plotColumn] = List<DateTime>.from(data[plotColumn]!.map((e) => e));
        }
      }
      _data[seriesId] = SeriesData.fromData(
        data: columns,
        plotColumns: plotColumns,
        dataIds: dataIds,
      );
    }
    throw DataAccessException("Unknown data source: $dataSource");
  }

  /// Check if two [SchemaField]s are compatible
  bool isFieldCompatible(SchemaField field1, SchemaField field2) => throw UnimplementedError();

  @override
  String toString() => "DataCenter:[${databases.keys}]";

  Map<UniqueId, SeriesData> get data => {..._data};
}

class DataId {
  final List<dynamic> keys;
  final String dataSource;

  DataId(this.keys, this.dataSource);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DataId) return false;
    if (keys.length != other.keys.length) return false;
    for (int i = 0; i < keys.length; i++) {
      if (keys[i] != other.keys[i]) return false;
    }
    return dataSource == other.dataSource; // Added check for dataSource
  }

  @override
  int get hashCode {
    int hash = dataSource.hashCode; // Added dataSource to the initial hash value
    return keys.fold(hash, (int hash, dynamic key) => hash * 31 + key.hashCode);
  }
}
