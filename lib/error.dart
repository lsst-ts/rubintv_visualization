import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

void reportError(String message) {
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
}
