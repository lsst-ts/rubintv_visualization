import 'dart:async';
import 'dart:developer' as developer;
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:rubintv_visualization/io.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/app.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/state/time_machine.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/data.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future main() async {
  DataCenter dataCenter = DataCenter();
  await dotenv.load(fileName: ".env");
  runApp(DemoApp(dataCenter: dataCenter, port: int.parse(dotenv.env['PORT'] as String)));
}

class DemoApp extends StatefulWidget {
  final DataCenter dataCenter;
  final int port;
  const DemoApp({super.key, required this.dataCenter, required this.port});

  @override
  DemoAppState createState() => DemoAppState();
}

String getWebsocketUrl(int port) {
  // Retrieves the current URL of the web app
  Uri uri = Uri.parse(html.window.location.href);

  // Builds the base URL using the host and the path
  String wsUrl = 'ws://${uri.host}:$port${uri.path}ws/client';
  return wsUrl;
}

class DemoAppState extends State<DemoApp> {
  final StreamController<String> streamController = StreamController<String>.broadcast();

  /// The websocket connection to the analysis service.
  late final WebSocketChannel webSocket;

  /// Whether or not the websocket is connected.
  bool _isConnected = false;

  /// The last message received from the analysis service.
  List<String> messageQueue = [];

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      String wsUrl = getWebsocketUrl(widget.port);
      print("Connecting to websocket at $wsUrl");
      webSocket = WebSocketChannel.connect(Uri.parse('$wsUrl'));
      webSocket.stream.listen(
        (event) {
          streamController.add(event);
        },
        onDone: () {
          developer.log('WebSocket connection closed.', name: "rubinTV.visualization.main");
          setState(() {
            _isConnected = false;
          });
        },
        onError: (error) {
          developer.log('WebSocket error: $error.', name: "rubinTV.visualization.main");
        },
      );

      webSocket.sink.add(LoadSchemaCommand().toJson());
      _isConnected = true;
    } catch (e) {
      developer.log('WebSocket connection failed: $e', name: "rubinTV.visualization.main");
    }
  }

  @override
  void dispose() {
    webSocket.sink.close();
    streamController.close();
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    print("building main app");
    ThemeData themeData = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF058b8c)),
      useMaterial3: true,
    );
    themeData = themeData.copyWith(scaffoldBackgroundColor: themeData.colorScheme.secondaryContainer);

    AppTheme theme = AppTheme(
      themeData: themeData,
    );

    Workspace workspace = Workspace(theme: theme, webSocket: webSocket);

    // Initialize the Redux store
    Store<AppState> store = Store<AppState>(
      appReducer,
      initialState: AppState(
        timeMachine: TimeMachine.init(workspace),
      ),
      distinct: true,
      //middleware: [webSocketMiddleware],
    );

    // Listen to WebSocket messages and dispatch actions
    streamController.stream.listen((message) {
      store.dispatch(WebSocketReceiveMessageAction(dataCenter: widget.dataCenter, message: message));
    });

    Size screenSize = MediaQuery.of(context).size;

    return StoreProvider<AppState>(
      store: store,
      child: MaterialApp(
        title: 'rubinTV visualization',
        theme: theme.themeData,
        home: Scaffold(
          body: StoreConnector<AppState, _WorkspaceViewModel>(
            distinct: true,
            converter: (store) => _WorkspaceViewModel(
              isConnected: _isConnected,
              appState: store.state,
              dispatch: store.dispatch,
            ),
            builder: (BuildContext context, _WorkspaceViewModel model) => WorkspaceViewer(
              size: screenSize,
              workspace: model.info,
              dataCenter: widget.dataCenter,
              dispatch: model.dispatch,
              isConnected: model.isConnected,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceViewModel {
  final AppState appState;
  final bool isConnected;
  final DispatchAction dispatch;

  const _WorkspaceViewModel({
    required this.appState,
    required this.isConnected,
    required this.dispatch,
  });

  /// The current state of the app
  AppState get state => appState;

  @override
  bool operator ==(Object other) => other is _WorkspaceViewModel && state == other.state;

  @override
  int get hashCode => state.hashCode;

  Workspace get info => appState.timeMachine.currentState;
}
