import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/query.dart';
import 'package:rubintv_visualization/workspace/data.dart';

bool _axesValid(Map<AxisId, SchemaField> fields, List<AxisId> axes) {
  if (axes.length != fields.length) {
    return false;
  }
  for (AxisId axis in axes) {
    if (!fields.containsKey(axis)) {
      return false;
    }
  }
  return true;
}

@immutable
class SeriesId {
  final UniqueId windowId;
  final BigInt id;

  const SeriesId({required this.id, required this.windowId});

  static SeriesId fromString(String id) {
    List<String> parts = id.split("-");
    return SeriesId(id: BigInt.parse(parts[1]), windowId: UniqueId.fromString(parts[0]));
  }

  @override
  bool operator ==(Object other) => other is SeriesId && other.windowId == windowId && other.id == id;

  @override
  int get hashCode => windowId.hashCode ^ id.hashCode;

  @override
  String toString() => "SeriesId<$shortString>";

  String get shortString => "${windowId.id}-$id";
}

@immutable
class SeriesInfo {
  final SeriesId id;
  final String name;
  final Marker? marker;
  final ErrorBars? errorBars;
  final List<AxisId> axes;
  final Map<AxisId, SchemaField> fields;
  final Query? query;

  const SeriesInfo({
    required this.id,
    required this.name,
    this.marker,
    this.errorBars,
    required this.axes,
    required this.fields,
    this.query,
  });

  SeriesInfo copyWith({
    SeriesId? id,
    String? name,
    Marker? marker,
    ErrorBars? errorBars,
    List<AxisId>? axes,
    Map<AxisId, SchemaField>? fields,
    Query? query,
  }) =>
      SeriesInfo(
        id: id ?? this.id,
        name: name ?? this.name,
        fields: fields ?? this.fields,
        axes: axes ?? this.axes,
        marker: marker ?? this.marker,
        errorBars: errorBars ?? this.errorBars,
        query: query ?? this.query,
      );

  SeriesInfo copy() => copyWith();

  @override
  String toString() => "Series<$id:$name>";

  Series? toSeries() {
    SeriesData? seriesData = DataCenter().getSeriesData(id);
    if (seriesData == null) {
      return null;
    }
    return Series(
      id: id,
      name: name,
      marker: marker,
      errorBars: errorBars,
      data: seriesData,
    );
  }
}
