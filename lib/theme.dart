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

import 'package:flutter/material.dart';
import 'package:rubin_chart/rubin_chart.dart';

/// The theme of the application.
class AppTheme {
  /// The Flutter theme data.
  final ThemeData themeData;

  /// The style for the query text.
  final TextStyle _queryStyle;

  /// The style for the title text.
  final TextStyle _titleStyle;

  /// The style for the axis labels.
  final TextStyle _axisLabelStyle;

  /// The width of the spacer between queries.
  final double querySpacerWidth;

  /// The speed of the animation.
  final Duration animationSpeed;

  /// The offset for a new window.
  final Offset newWindowOffset;

  /// The size for a new plot.
  final Size newPlotSize;

  /// The width of the resize interaction.
  final double resizeInteractionWidth;

  /// The height of the toolbar.
  final double toolbarHeight;

  /// The color of the wire that connects queries in the QueryEditor.
  final Color wireColor;

  /// The thickness of the wire that connects queries in the QueryEditor.
  final double wireThickness;

  // Chart settings
  final ChartTheme chartTheme;

  const AppTheme({
    required this.themeData,
    TextStyle queryStyle = const TextStyle(
      fontSize: 20,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      inherit: false,
      height: 1.0,
    ),
    TextStyle titleStyle = const TextStyle(
      fontSize: 20,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      inherit: false,
      height: 1.0,
    ),
    TextStyle axisLabelStyle = const TextStyle(
      fontSize: 20,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      inherit: false,
      height: 1.0,
    ),
    this.querySpacerWidth = 10,
    this.animationSpeed = const Duration(milliseconds: 500),
    this.newWindowOffset = const Offset(20, 20),
    this.newPlotSize = const Size(600, 400),
    this.resizeInteractionWidth = kMinInteractiveDimension / 4,
    this.toolbarHeight = 40,
    this.wireColor = Colors.red,
    this.wireThickness = 4,
    this.chartTheme = const ChartTheme(),
  })  : _queryStyle = queryStyle,
        _titleStyle = titleStyle,
        _axisLabelStyle = axisLabelStyle;

  /// Get the queryStyle with a color specified by the theme.
  TextStyle get queryStyle => _queryStyle.copyWith(color: themeData.colorScheme.primary);

  /// Get the queryOperatorStyle with a color specified by the theme.
  TextStyle get queryOperatorStyle => _queryStyle.copyWith(color: themeData.colorScheme.secondary);

  /// Get the queryFieldStyle with a color specified by the theme.
  TextStyle get titleStyle => _titleStyle.copyWith(color: themeData.colorScheme.primary);

  /// Get the queryFieldStyle with a color specified by the theme.
  TextStyle get axisLabelStyle => _axisLabelStyle.copyWith(color: themeData.colorScheme.primary);

  /// Get the queryTextDecorationTheme with a color specified by the theme.
  InputDecorationTheme get queryTextDecorationTheme => InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: themeData.primaryColorDark,
          ),
        ),
        //contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
      );

  /// Get the queryTextDecoration with a color specified by the theme.
  InputDecoration get queryTextDecoration => InputDecoration(
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: themeData.primaryColorDark,
          ),
        ),
        //contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
      );

  /// Alternate between secondary and tertiary container colors for the operators
  Color operatorQueryColor(int depth) => [
        themeData.colorScheme.secondaryContainer,
        themeData.colorScheme.tertiaryContainer,
      ][depth % 2];
}
