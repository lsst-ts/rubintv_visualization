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

import 'package:flutter/material.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/websocket.dart';
import 'package:rubintv_visualization/workspace/state.dart';
import 'package:rubintv_visualization/workspace/viewer.dart';

/// The main application widget.
class MainApp extends StatefulWidget {
  /// The URI of the WebSocket server.
  final Uri websocketUri;

  /// The version of the application.
  final AppVersion version;

  const MainApp({
    super.key,
    required this.websocketUri,
    required this.version,
  });

  @override
  MainAppState createState() => MainAppState();
}

/// The state of the [MainApp] widget.
class MainAppState extends State<MainApp> {
  /// Initialize the WebSocket connection.
  @override
  void initState() {
    super.initState();
    developer.log('Connecting to WebSocket at ${widget.websocketUri}', name: 'rubinTV.visualization.app');
    WebSocketManager().connect(widget.websocketUri);
  }

  /// Close the WebSocket connection.
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
          version: widget.version,
        ),
      ),
    );
  }
}
