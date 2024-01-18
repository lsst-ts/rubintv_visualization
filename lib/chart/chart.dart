import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rubintv_visualization/chart/axis.dart';
import 'package:rubintv_visualization/chart/legend.dart';
import 'package:rubintv_visualization/chart/marker.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/utils.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:rubintv_visualization/workspace/window.dart';

/// Persistable information to generate a chart
abstract class Chart extends Window {
  final Map<UniqueId, Series> _series;
  final ChartLegend legend;
  final List<PlotAxis?> _axes;

  /// Whether or not to use the global query for all series in this [Chart].
  final bool useGlobalQuery;

  Chart(
      {required super.id,
      required super.offset,
      super.title,
      required super.size,
      required Map<UniqueId, Series> series,
      required List<PlotAxis?> axes,
      required this.legend,
      required this.useGlobalQuery})
      : _series = Map.unmodifiable(series),
        _axes = List.unmodifiable(axes);

  /// Return a copy of the internal [Map] of [Series], to prevent updates.
  Map<UniqueId, Series> get series => {..._series};

  /// Return a copy of the internal [List] of [PlotAxis], to prevent updates.
  List<PlotAxis?> get axes => [..._axes];

  @override
  Chart copyWith({
    UniqueId? id,
    Offset? offset,
    Size? size,
    String? title,
    Map<UniqueId, Series>? series,
    List<PlotAxis?>? axes,
    ChartLegend? legend,
    bool? useGlobalQuery,
  });

  /// Create a new [Widget] to display in a [WorkspaceViewer].
  @override
  Widget createWidget(BuildContext context) => RubinChart(chart: this);

  /// Create the internal chart, not including the [ChartLegend].
  Widget createInternalChart({
    required AppTheme theme,
    required DataCenter dataCenter,
    required Size size,
    required WindowUpdateCallback dispatch,
  });

  /// Whether or not at least one [PlotAxis] has been set.
  bool get hasAxes => axes.isNotEmpty;

  /// Whether or not at least one [Series] has been initialized.
  bool get hasSeries => _series.isNotEmpty;

  /// Update [Chart] when [Series] is updated.
  Chart onSeriesUpdate({
    required Series series,
    required DataCenter dataCenter,
  }) {
    List<PlotAxis?> newAxes = [...axes];

    // Update the bounds for each unfixed axis
    for (int i = 0; i < series.fields.length; i++) {
      SchemaField field = series.fields[i];
      PlotAxis? axis = axes[i];

      if (axis == null) {
        axis = PlotAxis(
          label: field.asLabel,
          bounds: field.bounds,
          orientation: i % 2 == 0 ? AxisOrientation.horizontal : AxisOrientation.vertical,
        );
      } else if (field.bounds != null && axis.bounds != null) {
        // Update the [PlotAxis] bounds
        Bounds newBounds = axis.bounds!;
        if (newBounds.min == newBounds.max) {
          newBounds == field.bounds;
        } else if (!axis.boundsFixed) {
          newBounds = newBounds | field.bounds!;
        }
        axis = axis.copyWith(bounds: newBounds);
      }
      newAxes[i] = axis;
    }
    return copyWith(axes: newAxes);
  }

  /// Check if a series is compatible with this chart.
  /// Any mismatched columns have their indices returned.
  List<int>? canAddSeries({
    required Series series,
    required DataCenter dataCenter,
  }) {
    final List<int> mismatched = [];
    // Check that the series has the correct number of columns and axes
    if (series.fields.length != axes.length) {
      developer.log("bad axes", name: "rubin_chart.core.chart.dart");
      return null;
    }
    for (int i = 0; i < series.fields.length; i++) {
      for (Series otherSeries in _series.values) {
        // Check that the new series is compatible with the existing series
        if (!dataCenter.isFieldCompatible(otherSeries.fields[i], series.fields[i])) {
          developer.log(
            "Incompatible fields ${otherSeries.fields[i]} and ${series.fields[i]}",
            name: "rubin_chart.core.chart.dart",
          );
          mismatched.add(i);
        }
      }
    }
    return mismatched;
  }

  /// Update [Chart] when [Series] is updated.
  Chart addSeries({
    required Series series,
    required DataCenter dataCenter,
  }) {
    Map<UniqueId, Series> newSeries = {..._series};
    newSeries[series.id] = series;
    Chart result = copyWith(series: newSeries);
    return result.onSeriesUpdate(series: series, dataCenter: dataCenter);
  }

  /// Create a new empty Series for this [Chart].
  Series nextSeries({required DataCenter dataCenter});

  int get nMaxAxes;

  MarkerSettings getMarkerSettings({
    required Series series,
    required AppTheme theme,
  }) {
    if (series.marker != null) {
      // The user specified a marker for this [Series], so use it.
      return series.marker!;
    }
    // The user did not specify a marker, so use the default marker with the color updated
    return MarkerSettings(
      color: theme.getMarkerColor(_series.keys.toList().indexOf(series.id)),
      edgeColor: theme.getMarkerEdgeColor(_series.keys.toList().indexOf(series.id)),
    );
  }

  @override
  Widget? createToolbar(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return Row(children: [
      IconButton(
        icon: useGlobalQuery
            ? const Icon(Icons.travel_explore, color: Colors.green)
            : const Icon(Icons.public_off, color: Colors.grey),
        onPressed: () {
          workspace.dispatch(UpdateChartGlobalQueryAction(
            useGlobalQuery: !useGlobalQuery,
            dataCenter: workspace.dataCenter,
            chartId: id,
          ));
        },
      ),
      const SizedBox(width: 10),
      Container(
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            workspace.dispatch(RemoveWindowAction(this));
          },
        ),
      )
    ]);
  }
}

/// A chart containing a legend.
class RubinChart extends StatelessWidget {
  final Chart chart;

  const RubinChart({
    super.key,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    DataCenter dataCenter = workspace.dataCenter;

    Size size = chart.size;

    ChartLegend legend = chart.legend;
    if (legend.location == ChartLegendLocation.right) {
      return SizedBox(
        height: size.height,
        width: size.width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
              return chart.createInternalChart(
                theme: workspace.theme,
                dataCenter: dataCenter,
                size: Size(
                  constraints.maxWidth,
                  size.height,
                ),
                dispatch: workspace.dispatch,
              );
            })),
            VerticalChartLegendViewer(
              theme: workspace.theme,
              chart: chart,
            ),
          ],
        ),
      );
    }
    throw UnimplementedError("ChartLegendLocation ${chart.legend.location} not yet supported");
  }

  /// Implement the [RubinChart.of] method to allow children
  /// to find this container based on their [BuildContext].
  static RubinChart of(BuildContext context) {
    final RubinChart? result = context.findAncestorWidgetOfExactType<RubinChart>();
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('RubinChart.of() called with a context that does not '
              'contain a RubinChart.'),
          ErrorDescription('No RubinChart ancestor could be found starting from the context '
              'that was passed to RubinChart.of().'),
          ErrorHint('This probably happened when an interactive child was created '
              'outside of a RubinChart'),
          context.describeElement('The context used was')
        ]);
      }
      return true;
    }());
    return result!;
  }
}
