import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rubintv_visualization/utils/browser_logger.dart';

void reportError(String message) {
  // Show toast to user
  Fluttertoast.showToast(
    msg: message,
    toastLength: Toast.LENGTH_LONG,
    gravity: ToastGravity.CENTER,
    timeInSecForIosWeb: 5,
    backgroundColor: Colors.red,
    webBgColor: "#e74c3c",
    textColor: Colors.white,
    fontSize: 16.0,
  );

  // Also log to file
  logWithFile(
    message,
    name: 'rubinTV.error',
    level: 3, // ERROR level
  );
}
