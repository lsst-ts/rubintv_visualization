import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:developer' as developer;

class WebSocketManager {
  /// Make the WebSocketManager a singleton.
  static final WebSocketManager _singleton = WebSocketManager._internal();

  /// The WebSocket connection.
  WebSocketChannel? _channel;

  /// The stream controller for messages.
  final StreamController<Map<String, dynamic>> _controller = StreamController.broadcast();

  /// The stream of messages.
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  /// The WebSocketManager factory constructor.
  factory WebSocketManager() {
    return _singleton;
  }

  /// The private WebSocketManager constructor.
  WebSocketManager._internal();

  Future<void> connect(Uri uri) async {
    try {
      if (_channel != null) {
        await _channel!.sink.close();
      }
      developer.log("Connecting to websocket at $uri", name: "rubinTV.visualization.websocket");
      _channel =
          WebSocketChannel.connect(uri); // Use WebSocketChannel.connect for a platform-agnostic approach

      _channel!.stream.listen((data) {
        if (data is String) {
          Map<String, dynamic> message = jsonDecode(data);
          _controller.add(message);
        } else {
          developer.log("Received non-string data from the WebSocket",
              name: 'gpt_tutor.io.message.WebSocketManager');
        }
      }, onError: (error) {
        developer.log("Error in WebSocket: $error", name: 'rubinTV.visualization.websocket');
        // Handle errors or attempt to reconnect
      }, onDone: () {
        developer.log("WebSocket connection closed", name: 'rubinTV.visualization.websocket');
        // Handle the connection being closed
      });
    } catch (e) {
      developer.log('Failed to connect to $uri: $e', name: 'rubinTV.visualization.websocket');
      Fluttertoast.showToast(
          msg: "Failed to connect to $uri",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.CENTER,
          timeInSecForIosWeb: 5,
          backgroundColor: Colors.red,
          webBgColor: "#e74c3c",
          textColor: Colors.white,
          fontSize: 16.0);
    }
  }

  /// Send a message if the socket is connected.
  void sendMessage(String message) {
    if (_channel != null) {
      _channel!.sink.add(message);
      developer.log("Message sent: $message", name: 'rubinTV.visualization.websocket');
    } else {
      developer.log("WebSocket is not connected.", name: 'rubinTV.visualization.websocket');
    }
  }

  Future<void> close() async {
    if (_channel != null) {
      await _channel!.sink.close();
      _channel = null;
      _controller.close();
      developer.log("WebSocket connection closed manually.", name: 'rubinTV.visualization.websocket');
    }
  }

  /// Automatically attempt to reconnect.
  void reconnect(Uri uri) {
    developer.log("Attempting to reconnect to WebSocket...", name: 'rubinTV.visualization.websocket');
    connect(uri);
  }

  bool get isConnected => _channel != null;
}
