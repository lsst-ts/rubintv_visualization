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
import 'dart:convert';
import 'package:rubintv_visualization/error.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:developer' as developer;

/// A singleton class to manage the WebSocket connection.
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
      reportError("Failed to connect to $uri: $e");
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
