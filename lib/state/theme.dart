import 'package:flutter/material.dart';

class AppTheme {
  final ThemeData themeData;
  final TextStyle _queryStyle;
  final TextStyle _titleStyle;
  final double querySpacerWidth;
  final Duration animationSpeed;
  final Offset newWindowOffset;
  final Size newPlotSize;
  final double resizeInteractionWidth;
  final double toolbarHeight;
  final Color wireColor;
  final double wireThickness;

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
    this.querySpacerWidth = 10,
    this.animationSpeed = const Duration(milliseconds: 500),
    this.newWindowOffset = const Offset(20, 20),
    this.newPlotSize = const Size(600, 400),
    this.resizeInteractionWidth = kMinInteractiveDimension / 4,
    this.toolbarHeight = 40,
    this.wireColor = Colors.red,
    this.wireThickness = 4,
  })  : _queryStyle = queryStyle,
        _titleStyle = titleStyle;

  TextStyle get queryStyle =>
      _queryStyle.copyWith(color: themeData.colorScheme.primary);
  TextStyle get queryOperatorStyle =>
      _queryStyle.copyWith(color: themeData.colorScheme.secondary);
  TextStyle get titleStyle =>
      _titleStyle.copyWith(color: themeData.colorScheme.primary);

  InputDecorationTheme get queryTextDecorationTheme => InputDecorationTheme(
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: themeData.primaryColorDark,
          ),
        ),
        //contentPadding: const EdgeInsets.symmetric(vertical: 5.0),
      );

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
