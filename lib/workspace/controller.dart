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

import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/workspace/state.dart';

/// A [ControlCenter] is a singleton class that is used to manage stream controllers
/// in the workspace.
class ControlCenter {
  static final ControlCenter _instance = ControlCenter._internal();

  factory ControlCenter() {
    return _instance;
  }

  ControlCenter._internal() {
    // Initialization logic here
  }

  /// A [Stream] that broadcasts the global query.
  Stream<GlobalQuery?> get globalQueryStream => _globalQueryController.stream;

  /// A [StreamController] that broadcasts the global query.
  final StreamController<GlobalQuery?> _globalQueryController = StreamController<GlobalQuery?>.broadcast();

  /// A [SelectionController] that manages the selection of data points.
  final SelectionController _selectionController = SelectionController();

  /// A [SelectionController] that manages the drill down of data points.
  final SelectionController _drillDownController = SelectionController();

  /// A [SelectionController] that manages the selection of data points.
  SelectionController get selectionController => _selectionController;

  /// A [SelectionController] that manages the drill down of data points.
  SelectionController get drillDownController => _drillDownController;

  /// Update the global query.
  void updateGlobalQuery(GlobalQuery? query) {
    _globalQueryController.add(query);
  }

  /// Update the selection data points.
  void updateSelection(Object chartId, Set<Object> dataPoints) {
    _selectionController.updateSelection(chartId, dataPoints);
  }

  /// Update the drill down data points.
  void updateDrillDown(Object chartId, Set<Object> dataPoints) {
    _drillDownController.updateSelection(chartId, dataPoints);
  }

  /// Dispose of the stream controllers.
  void dispose() {
    _globalQueryController.close();
    _selectionController.dispose();
    _drillDownController.dispose();
  }

  /// Reset the stream controllers.
  void reset() {
    _globalQueryController.add(null);
    _selectionController.reset();
    _drillDownController.reset();
  }
}
