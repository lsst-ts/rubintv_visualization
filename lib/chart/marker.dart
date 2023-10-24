import 'package:flutter/material.dart';

enum MarkerTypes {
  circle,
  rectangle,
  unicode,
}

class MarkerSettings {
  final double size;
  final MarkerTypes type;
  final Color color;
  final Color? edgeColor;

  const MarkerSettings({
    this.size = 10,
    this.color = Colors.black,
    this.edgeColor = Colors.white,
    this.type = MarkerTypes.circle,
  });

  MarkerSettings copyWith({
    double? size,
    MarkerTypes? type,
    Color? color,
    Color? edgeColor,
  }) =>
      MarkerSettings(
        size: size ?? this.size,
        type: type ?? this.type,
        color: color ?? this.color,
        edgeColor: edgeColor ?? this.edgeColor,
      );
}

class ErrorBarSettings {
  final double width;
  final double headSize;
  final Color color;

  const ErrorBarSettings({
    this.width = 2,
    this.color = Colors.black,
    this.headSize = 20,
  });

  ErrorBarSettings copyWith({
    double? width,
    Color? color,
    double? headSize,
  }) =>
      ErrorBarSettings(
        width: width ?? this.width,
        color: color ?? this.color,
        headSize: headSize ?? this.headSize,
      );
}
