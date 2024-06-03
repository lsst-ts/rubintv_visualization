import 'dart:async';

import 'package:web/web.dart' as web;
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

Future main() async {
  DataCenter dataCenter = DataCenter();
  await dotenv.load(fileName: ".env");

  String host = web.window.location.hostname;
  String address = dotenv.env['ADDRESS'] as String;
  String port = dotenv.env['PORT'] as String;

  print("host is $host, address is $address, port is $port");

  String websocketUrl = Uri.decodeFull(
      Uri(scheme: 'ws', host: host, pathSegments: [address, 'ws/client'], port: int.tryParse(port))
          .toString());
  print(websocketUrl);

  AppVersion version = await getAppVersion();

  runApp(MainApp(dataCenter: dataCenter, websocketUrl: websocketUrl, version: version));
}
