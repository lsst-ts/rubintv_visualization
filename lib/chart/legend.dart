import 'package:flutter/material.dart';
import 'package:rubintv_visualization/chart/chart.dart';
import 'package:rubintv_visualization/chart/marker.dart';
import 'package:rubintv_visualization/editors/series.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/data.dart';

enum ChartLegendLocation {
  top,
  bottom,
  left,
  right,
  floating,
}

class ChartLegend {
  ChartLegendLocation location;
  Offset? offset;

  ChartLegend({
    required this.location,
    this.offset,
  });
}

class VerticalChartLegendViewer extends StatefulWidget {
  final AppTheme theme;
  final Chart chart;

  const VerticalChartLegendViewer({
    super.key,
    required this.theme,
    required this.chart,
  });

  @override
  VerticalChartLegendViewerState createState() => VerticalChartLegendViewerState();
}

class VerticalChartLegendViewerState extends State<VerticalChartLegendViewer> {
  AppTheme get theme => widget.theme;
  List<Series> get series => widget.chart.series.values.toList();

  Future<void> _editState(BuildContext context, Series series, isNew) async {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: SeriesEditor(
          theme: theme,
          series: series,
          isNew: isNew,
          dataCenter: workspace.dataCenter,
          dispatch: workspace.dispatch,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    DataCenter dataCenter = workspace.dataCenter;

    final List<Widget> children = [];
    for (Series item in series) {
      MarkerSettings marker = widget.chart.getMarkerSettings(series: item, theme: theme);
      children.add(GestureDetector(
          onTap: () {
            _editState(context, item, widget.chart).then((_) {
              setState(() {});
            });
          },
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Marker(
              size: marker.size,
              color: marker.color,
              edgeColor: marker.edgeColor,
              markerType: marker.type,
            ),
            const SizedBox(width: 5),
            Text(item.name, style: theme.legendStyle),
          ])));
    }

    children.add(IconButton(
      icon: const Icon(Icons.add_circle, color: Colors.green),
      onPressed: () {
        Series series = widget.chart.nextSeries(dataCenter: dataCenter);
        _editState(context, series, true).then((_) {
          setState(() {});
        });
      },
    ));

    return Column(children: [
      const Spacer(),
      Container(
        padding: const EdgeInsets.fromLTRB(5, 10, 5, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: theme.themeData.colorScheme.secondaryContainer,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
      const Spacer(),
    ]);
  }
}
