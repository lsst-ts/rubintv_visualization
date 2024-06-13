import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/data.dart';

class AppVersion {
  final int major;
  final int minor;
  final int patch;
  final String buildNumber;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.buildNumber,
  });

  static AppVersion fromString(String version, String buildNumber) {
    List<String> parts = version.split('.');
    if (parts.length != 3) throw Exception('Invalid version string: $version');

    return AppVersion(
      major: int.parse(parts[0]),
      minor: int.parse(parts[1]),
      patch: int.parse(parts[2]),
      buildNumber: buildNumber,
    );
  }

  @override
  String toString() => '$major.$minor.$patch';
}

class MainApp extends StatefulWidget {
  final DataCenter dataCenter;
  final String websocketUrl;
  final AppVersion version;
  const MainApp({
    super.key,
    required this.dataCenter,
    required this.websocketUrl,
    required this.version,
  });

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  @override
  void initState() {
    super.initState();
    developer.log('Connecting to WebSocket at ${widget.websocketUrl}', name: 'rubinTV.visualization.app');
    WebSocketManager().connect(widget.websocketUrl);
  }

  @override
  void dispose() {
    WebSocketManager().close();
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    developer.log("building main app", name: "rubinTV.visualization.app");
    ThemeData themeData = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF058b8c)),
      useMaterial3: true,
    );
    themeData = themeData.copyWith(scaffoldBackgroundColor: themeData.colorScheme.secondaryContainer);

    AppTheme theme = AppTheme(
      themeData: themeData,
    );

    Size screenSize = MediaQuery.of(context).size;

    return MaterialApp(
      title: 'rubinTV visualization',
      theme: theme.themeData,
      home: Scaffold(
        body: WorkspaceViewer(
          size: screenSize,
          theme: theme,
          dataCenter: widget.dataCenter,
        ),
      ),
    );
  }
}
