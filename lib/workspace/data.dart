import 'dart:io';

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
  date,
  time,
  dateTime,
}

Map<Type, DataType> _dataTypeLookup = {
  String: DataType.string,
  int: DataType.integer,
  double: DataType.double,
  DateTime: DataType.dateTime,
};

class SchemaField {
  final String name;
  final String? unit;
  final String? description;

  const SchemaField({
    required this.name,
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
  final Map<String, SchemaField> fields;
  const Schema(this.fields);

  static Schema fromFields(List<SchemaField> fields) =>
      Schema({for (SchemaField field in fields) field.name: field});
}

class DataSet {
  final int id;
  final String name;
  final Schema schema;

  DataSet._({
    required this.id,
    required this.name,
    required this.schema,
  });

  static DataSet init({
    required String name,
    required Schema schema,
  }) =>
      DataSet._(
        id: _nextDataset++,
        name: name,
        schema: schema,
      );

  @override
  String toString() => "DataSet<$name>";
}

class DataCenterUpdate {}

class DataSetLoaded extends DataCenterUpdate {
  DataSet dataSet;
  DataSetLoaded({required this.dataSet});
}

class DataCenter {
  final Map<String, DataSet> _dataSets = {};

  DataCenter();

  Map<String, DataSet> get dataSets => {..._dataSets};

  void addDataSet(DataSet dataSet) {
    _dataSets[dataSet.name] = dataSet;
  }

  /// Check if two [SchemaField]s are compatible
  bool isFieldCompatible(SchemaField field1, SchemaField field2) =>
      throw UnimplementedError();

  @override
  String toString() => "DataCenter:[${dataSets.keys}]";
}
