import 'dart:async';

import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/workspace/state.dart';

class ControlCenter {
  static final ControlCenter _instance = ControlCenter._internal();

  factory ControlCenter() {
    return _instance;
  }

  ControlCenter._internal() {
    // Initialization logic here
  }

  Stream<GlobalQuery?> get globalQueryStream => _globalQueryController.stream;

  final StreamController<GlobalQuery?> _globalQueryController = StreamController<GlobalQuery?>.broadcast();
  final SelectionController selectionController = SelectionController();
  final SelectionController drillDownController = SelectionController();

  void updateGlobalQuery(GlobalQuery? query) {
    _globalQueryController.add(query);
  }

  void updateSelection(Object? chartId, Set<Object> dataPoints) {
    selectionController.updateSelection(chartId, dataPoints);
  }

  void updateDrillDown(Object? chartId, Set<Object> dataPoints) {
    drillDownController.updateSelection(chartId, dataPoints);
  }

  void dispose() {
    _globalQueryController.close();
  }
}
