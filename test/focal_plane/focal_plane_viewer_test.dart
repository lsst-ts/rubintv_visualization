import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mockito/mockito.dart';

import 'package:rubintv_visualization/focal_plane/viewer.dart';
import 'package:rubintv_visualization/focal_plane/instrument.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/theme.dart';
import 'package:rubintv_visualization/workspace/window.dart';
import 'package:rubintv_visualization/workspace/state.dart';

// Import the mock WorkspaceBloc
import 'mock_workspace_bloc.mocks.dart';

void main() {
  late MockWorkspaceBloc mockWorkspaceBloc;

  setUp(() {
    // Initialize the mocked WorkspaceBloc
    mockWorkspaceBloc = MockWorkspaceBloc();
    when(mockWorkspaceBloc.add(any)).thenAnswer((invocation) {
      print('WorkspaceBloc.add called with: ${invocation.positionalArguments.first}');
    });
  });

  testWidgets('FocalPlaneViewer renders correctly and handles navigation', (WidgetTester tester) async {
    // Create a theme
    AppTheme theme = AppTheme(themeData: ThemeData.light());

    final workspaceState = WorkspaceState(
      theme: theme,
      version: const AppVersion(major: 1, minor: 0, patch: 0, buildNumber: "test"),
      status: WorkspaceStatus.ready,
      windows: {},
    );

    // Create mock detectors
    final detectors = createMockedDetectors();

    // Create a mock instrument
    final instrument = Instrument(name: "Test instrument", detectors: detectors);

    // Create a test window
    final testWindow = WindowMetaData(
        size: const Size(400, 400),
        offset: const Offset(0, 0),
        bloc: WindowBloc(WindowState(id: UniqueId.next(), windowType: WindowTypes.focalPlane)));

    await tester.pumpWidget(
      BlocProvider<WorkspaceBloc>(
        create: (_) => mockWorkspaceBloc,
        child: FocalPlaneViewer(
          window: testWindow,
          instrument: instrument,
          // Initially select the center detector
          selectedDetector: detectors[4],
          workspace: workspaceState,
        ),
      ),
    );

    // Verify that the widget renders detectors
    expect(find.byType(CustomPaint), findsOneWidget);

    // Simulate key navigation
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    // Verify that the correct event was dispatched to WorkspaceBloc
    verify(mockWorkspaceBloc.add(
      argThat(isA<SelectDetectorEvent>().having((e) => e.detector, 'detector', detectors[5])),
    )).called(1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    verify(mockWorkspaceBloc.add(
      argThat(isA<SelectDetectorEvent>().having((e) => e.detector, 'detector', detectors[8])),
    )).called(1);
  });
}

List<Detector> createMockedDetectors() {
  // Dimensions for each detector
  const double detectorSize = 100.0;
  const double gap = 10.0; // Gap between detectors

  List<Detector> detectors = [];

  for (int row = 0; row < 3; row++) {
    for (int col = 0; col < 3; col++) {
      int id = row * 3 + col;
      double left = col * (detectorSize + gap);
      double top = (2 - row) * (detectorSize + gap); // Top row is at the highest y-coordinate

      detectors.add(
        Detector(
          id: id,
          name: id.toString(), // Name as string version of the ID
          bbox: Rect.fromLTWH(left, top, detectorSize, detectorSize),
          corners: [
            Offset(left, top),
            Offset(left + detectorSize, top),
            Offset(left + detectorSize, top + detectorSize),
            Offset(left, top + detectorSize),
          ],
        ),
      );
    }
  }

  return detectors;
}
