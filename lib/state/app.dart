import 'package:rubintv_visualization/state/time_machine.dart';
import 'package:rubintv_visualization/state/workspace.dart';

class AppVersion {
  final int major;
  final int minor;
  final int patch;
  final String buildNumber;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.buildNumber,
  });

  static AppVersion fromString(String version, String buildNumber) {
    List<String> parts = version.split('.');
    if (parts.length != 3) throw Exception('Invalid version string: $version');

    return AppVersion(
      major: int.parse(parts[0]),
      minor: int.parse(parts[1]),
      patch: int.parse(parts[2]),
      buildNumber: buildNumber,
    );
  }

  @override
  String toString() => '$major.$minor.$patch';
}

/// Global State for the entire App.
///
/// Since rubin_chart uses the redux design pattern there is a single
/// state for the entire app, which is kept in a
/// flutter.redux [Store] and is used to update the entire
/// app as necessary on changes.
class AppState {
  /// The manipulated expressions
  final TimeMachine<Workspace> timeMachine;

  /// The version of the app
  final AppVersion version;

  const AppState({
    required this.timeMachine,
    required this.version,
  });

  /// Make a copy of the state with the specified terms updated
  AppState copyWith({
    TimeMachine<Workspace>? timeMachine,
    AppVersion? version,
  }) =>
      AppState(
        timeMachine: timeMachine ?? this.timeMachine,
        version: version ?? this.version,
      );

  /// Make an exact copy of the state
  AppState copy() => copyWith();
}

/// Main reducer for the entire app
AppState appReducer(AppState state, action) {
  TimeMachine<Workspace> workspaceState = workspaceReducer(state.timeMachine, action);
  if (workspaceState != state.timeMachine || action is WebSocketReceiveMessageAction) {
    return state.copyWith(timeMachine: workspaceState);
  }
  return state;
}
