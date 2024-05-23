import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rubintv_visualization/app.dart';
import 'package:rubintv_visualization/state/app.dart';
import 'package:rubintv_visualization/workspace/data.dart';

Future<AppVersion> getAppVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  String version = packageInfo.version;
  String buildNumber = packageInfo.buildNumber;

  print('App Version: $version');
  print('Build Number: $buildNumber');

  return AppVersion.fromString(version, buildNumber);
}

String getWebsocketUrl(String address, int port) {
  // Builds the base URL using the host and the path
  String wsUrl = 'ws://$address:$port/ws/client';
  return wsUrl;
}

Future main() async {
  DataCenter dataCenter = DataCenter();
  await dotenv.load(fileName: ".env");

  String websocketUrl =
      getWebsocketUrl(dotenv.env['ADDRESS'] as String, int.parse(dotenv.env['PORT'] as String));

  AppVersion version = await getAppVersion();

  runApp(MainApp(dataCenter: dataCenter, websocketUrl: websocketUrl, version: version));
}
