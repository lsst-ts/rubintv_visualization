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
import 'dart:developer' as developer;

import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rubintv_visualization/app.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// A function to get the current version of the application.
Future<AppVersion> getAppVersion() async {
  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  String version = packageInfo.version;
  String buildNumber = packageInfo.buildNumber;

  developer.log('App Version: $version', name: 'rubinTV.visualization.main');
  developer.log('Build Number: $buildNumber', name: 'rubinTV.visualization.main');

  return AppVersion.fromString(version, buildNumber);
}

/// The main function for the application.
Future main() async {
  DataCenter dataCenter = DataCenter();
  dataCenter.initialize();
  await dotenv.load(fileName: ".env");

  String host = web.window.location.hostname;
  String protocol = web.window.location.protocol == "https:" ? "wss" : "ws";
  String address = dotenv.get("ADDRESS", fallback: "");
  int? port = int.tryParse(dotenv.get("PORT", fallback: ""));

  developer.log(
    "${web.window.location.protocol}, host is $host, "
    "address is $address, port is $port, protocol is $protocol",
    name: 'rubinTV.visualization.main',
  );

  Uri websocketUrl = Uri(scheme: protocol, host: host, pathSegments: [address, 'client'], port: port);

  AppVersion version = await getAppVersion();

  runApp(MainApp(websocketUri: websocketUrl, version: version));
}
