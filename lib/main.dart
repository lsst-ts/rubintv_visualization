import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
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

void main() {
  DataCenter dataCenter = DataCenter();
  runApp(DemoApp(dataCenter: dataCenter));
}

class DemoApp extends StatefulWidget {
  final DataCenter dataCenter;
  const DemoApp({super.key, required this.dataCenter});

  @override
  DemoAppState createState() => DemoAppState();
}

class DemoAppState extends State<DemoApp> {
  final StreamController<DataCenterUpdate> streamController =
      StreamController.broadcast();

  /// The websocket connection to the analysis service.
  late final WebSocketChannel channel;

  /// Whether or not the websocket is connected.
  bool _isConnected = false;

  /// The last message received from the analysis service.
  List<String> messageQueue = [];

  // The address of the analysis service.
  String serviceAddress = "localhost";
  // The port of the analysis service.
  int servicePort = 2000;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  Future<void> _connect() async {
    try {
      channel = WebSocketChannel.connect(
          Uri.parse('ws://$serviceAddress:$servicePort/ws/client'));
      channel.stream.listen(
        (event) {
          setState(() {
            messageQueue.add(event);
          });
        },
        onDone: () {
          developer.log('WebSocket connection closed.',
              name: "rubinTV.visualization.main");
          setState(() {
            _isConnected = false;
          });
        },
        onError: (error) {
          developer.log('WebSocket error: $error.',
              name: "rubinTV.visualization.main");
        },
      );

      channel.sink.add(LoadSchemaCommand().toJson());
      _isConnected = true;
    } catch (e) {
      developer.log('WebSocket connection failed: $e',
          name: "rubinTV.visualization.main");
    }
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    ThemeData themeData = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF058b8c)),
      useMaterial3: true,
    );
    themeData = themeData.copyWith(
        scaffoldBackgroundColor: themeData.colorScheme.secondaryContainer);

    ChartTheme theme = ChartTheme(
      themeData: themeData,
    );

    Workspace workspace = Workspace(theme: theme);

    // By default use scalar algebra over the complex field
    Store<AppState> store = Store<AppState>(
      appReducer,
      initialState: AppState(
        timeMachine: TimeMachine.init(workspace),
      ),
      distinct: true,
    );

    Size screenSize = MediaQuery.of(context).size;

    if (messageQueue.isNotEmpty) {
      // Process the incoming messages in order
      store.dispatch(WebSocketReceiveMessageAction(
          dataCenter: widget.dataCenter, message: messageQueue.removeAt(0)));
    }

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
                dispatch: store.dispatch),
            builder: (BuildContext context, _WorkspaceViewModel model) =>
                WorkspaceViewer(
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
  bool operator ==(dynamic other) =>
      other is _WorkspaceViewModel && state == other.state;

  @override
  int get hashCode => state.hashCode;

  Workspace get info => appState.timeMachine.currentState;
}
