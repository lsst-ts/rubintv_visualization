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
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/query/primitives.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// The ID of a [Series].
/// Each series has a unique combination of a [WindowId] and the index of the series in the window.
@immutable
class SeriesId {
  /// The unique identifier for the window that contains the series.
  final UniqueId windowId;

  /// The unique identifier for the series in the window.
  final BigInt id;

  const SeriesId({required this.id, required this.windowId});

  /// Create a [SeriesId] from a string of the form "${windowId}-${SeriesId}".
  static SeriesId fromString(String id) {
    List<String> parts = id.split("-");
    return SeriesId(id: BigInt.parse(parts[1]), windowId: UniqueId.fromString(parts[0]));
  }

  /// Check if this [SeriesId] is equal to another object.
  @override
  bool operator ==(Object other) => other is SeriesId && other.windowId == windowId && other.id == id;

  /// Get the hash code for this [SeriesId].
  @override
  int get hashCode => windowId.hashCode ^ id.hashCode;

  /// Get a string representation of this [SeriesId].
  @override
  String toString() => "SeriesId<$shortString>";

  /// Get a short string representation of this [SeriesId] (the inverse of [fromString]).
  String get shortString => "${windowId.id}-$id";
}

/// Information used to create a [Series] in a chart.
@immutable
class SeriesInfo {
  /// The unique identifier for the series.
  final SeriesId id;

  /// The name of the series.
  final String name;

  /// The marker to use for the series.
  final Marker? marker;

  /// The error bars to use for the series.
  final ErrorBars? errorBars;

  /// The axes that the series is plotted on.
  final List<AxisId> axes;

  /// The fields that the series uses.
  final Map<AxisId, SchemaField> fields;

  /// A query used to load the series data.
  final QueryExpression? query;

  const SeriesInfo({
    required this.id,
    required this.name,
    this.marker,
    this.errorBars,
    required this.axes,
    required this.fields,
    this.query,
  });

  /// Make a copy of this [SeriesInfo] with the given fields updated.
  SeriesInfo copyWith({
    SeriesId? id,
    String? name,
    Marker? marker,
    ErrorBars? errorBars,
    List<AxisId>? axes,
    Map<AxisId, SchemaField>? fields,
  }) =>
      SeriesInfo(
        id: id ?? this.id,
        name: name ?? this.name,
        fields: fields ?? this.fields,
        axes: axes ?? this.axes,
        marker: marker ?? this.marker,
        errorBars: errorBars ?? this.errorBars,
        query: query,
      );

  /// Since the query can be changed to null, create a copy with a new query separately.
  SeriesInfo copyWithQuery(QueryExpression? query) => SeriesInfo(
        id: id,
        name: name,
        fields: fields,
        axes: axes,
        marker: marker,
        errorBars: errorBars,
        query: query,
      );

  SeriesInfo copy() => copyWith();

  @override
  String toString() => "Series<$id:$name>";

  /// Convert the [SeriesInfo] to a [Series].
  Series toSeries() {
    SeriesData? seriesData = DataCenter().getSeriesData(id);
    if (seriesData == null) {
      // Don't throw an exception - this is expected when data is still loading
      throw StateError("Data not available for series $id");
    }

    try {
      return Series(
        id: id,
        name: name,
        data: seriesData,
        marker: marker,
      );
    } catch (e) {
      // Re-throw with more context for actual conversion errors
      if (e is DataConversionException) {
        throw DataConversionException("Failed to convert series '$name': ${e.message}");
      }
      rethrow;
    }
  }

  /// Convert this [SeriesInfo] to a JSON object.
  Map<String, dynamic> toJson() {
    return {
      "id": id.shortString,
      "name": name,
      "marker": marker?.toJson(),
      "errorBars": errorBars?.toJson(),
      "axes": axes.map((e) => e.toJson()).toList(),
      "fields": Map<String, dynamic>.fromEntries(
          fields.entries.map((entry) => MapEntry(entry.key.toJson(), entry.value.toJson()))),
      "query": query?.toJson(),
    };
  }

  /// Create a [SeriesInfo] from a JSON object.
  static SeriesInfo fromJson(Map<String, dynamic> json) {
    try {
      Map<AxisId, SchemaField> fields = {};

      if (json["fields"] is List) {
        // Handle old format: list of pairs
        developer.log("Processing fields as list format", name: "rubintv.chart.series");
        for (dynamic fieldItem in json["fields"]) {
          if (fieldItem is List && fieldItem.length == 2) {
            var axisData = fieldItem[0];
            var fieldData = fieldItem[1];

            developer.log("Processing field pair: $axisData -> $fieldData", name: "rubintv.chart.series");

            if (axisData != null && fieldData != null) {
              AxisId axisId = AxisId.fromJson(axisData);
              SchemaField field = SchemaField.fromJson(fieldData as Map<String, dynamic>);
              fields[axisId] = field;
              developer.log("Field processed from list: $axisId -> ${field.name}",
                  name: "rubintv.chart.series");
            } else {
              developer.log("Skipping null field pair: $axisData -> $fieldData",
                  name: "rubintv.chart.series");
            }
          } else {
            developer.log("Invalid field item format: $fieldItem", name: "rubintv.chart.series");
          }
        }
      } else if (json["fields"] is Map) {
        // Handle new format: map
        developer.log("Processing fields as map format", name: "rubintv.chart.series");
        Map<String, dynamic> fieldsMap = json["fields"] as Map<String, dynamic>;
        for (MapEntry<String, dynamic> entry in fieldsMap.entries) {
          developer.log("Processing field: ${entry.key} -> ${entry.value}", name: "rubintv.chart.series");
          if (entry.value != null) {
            AxisId axisId = AxisId.fromJson(entry.key);
            SchemaField field = SchemaField.fromJson(entry.value as Map<String, dynamic>);
            fields[axisId] = field;
            developer.log("Field processed from map: ${axisId} -> ${field.name}",
                name: "rubintv.chart.series");
          } else {
            developer.log("Skipping null field value for key: ${entry.key}", name: "rubintv.chart.series");
          }
        }
      } else {
        developer.log("Unknown fields format: ${json["fields"].runtimeType}", name: "rubintv.chart.series");
        throw ArgumentError("Unknown fields format in JSON");
      }

      return SeriesInfo(
        id: SeriesId.fromString(json["id"]),
        name: json["name"],
        axes: List<AxisId>.from(json["axes"].map((e) => AxisId.fromJson(e))),
        fields: fields,
        query: json.containsKey("query") && json["query"] != null
            ? QueryExpression.fromJson(json["query"])
            : null,
      );
    } catch (e, stackTrace) {
      developer.log("Error in SeriesInfo.fromJson: $e",
          name: "rubintv.chart.series", error: e, stackTrace: stackTrace);
      developer.log("Full JSON: $json", name: "rubintv.chart.series");
      rethrow;
    }
  }
}
