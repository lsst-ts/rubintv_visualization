import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rubin_chart/rubin_chart.dart';

import 'package:rubintv_visualization/chart/base.dart';
import 'package:rubintv_visualization/chart/series.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/workspace/window.dart';

void main() {
  group('Row Count Dialog Tests', () {
    late ChartBloc chartBloc;

    setUp(() {
      chartBloc = ChartBloc(ChartState(
        id: UniqueId.next(),
        series: {},
        axisInfo: [],
        legend: null,
        useGlobalQuery: false,
        windowType: WindowTypes.cartesianScatter,
        tool: MultiSelectionTool.select,
        resetController: StreamController<ResetChartAction>.broadcast(),
      ));
    });

    tearDown(() {
      chartBloc.close();
    });

    test('RowCountDialogInfo should store all required information', () {
      final seriesId = SeriesId(id: BigInt.one, windowId: UniqueId.next());
      final seriesInfo = SeriesInfo(
        id: seriesId,
        name: 'test',
        axes: const [],
        fields: const {},
      );

      final dialogInfo = RowCountDialogInfo(
        rowCount: 150000,
        series: seriesInfo,
        dayObs: '2024-01-01',
        globalQuery: null,
      );

      expect(dialogInfo.rowCount, 150000);
      expect(dialogInfo.series.name, 'test');
      expect(dialogInfo.dayObs, '2024-01-01');
      expect(dialogInfo.globalQuery, null);
    });

    test('ChartState should handle pendingRowCountDialog correctly', () {
      final seriesId = SeriesId(id: BigInt.one, windowId: UniqueId.next());
      final seriesInfo = SeriesInfo(
        id: seriesId,
        name: 'test',
        axes: const [],
        fields: const {},
      );

      final dialogInfo = RowCountDialogInfo(
        rowCount: 150000,
        series: seriesInfo,
        dayObs: '2024-01-01',
        globalQuery: null,
      );

      final initialState = ChartState(
        id: UniqueId.next(),
        series: {},
        axisInfo: [],
        legend: null,
        useGlobalQuery: false,
        windowType: WindowTypes.cartesianScatter,
        tool: MultiSelectionTool.select,
        resetController: StreamController<ResetChartAction>.broadcast(),
      );

      final stateWithDialog = initialState.copyWith(
        pendingRowCountDialog: dialogInfo,
      );

      expect(stateWithDialog.pendingRowCountDialog, equals(dialogInfo));
      expect(stateWithDialog.pendingRowCountDialog?.rowCount, 150000);
    });

    test('ShowRowCountConfirmationEvent should set pendingRowCountDialog', () async {
      final seriesId = SeriesId(id: BigInt.one, windowId: UniqueId.next());
      final seriesInfo = SeriesInfo(
        id: seriesId,
        name: 'test',
        axes: const [],
        fields: const {},
      );

      chartBloc.add(ShowRowCountConfirmationEvent(
        rowCount: 150000,
        series: seriesInfo,
        dayObs: '2024-01-01',
        globalQuery: null,
      ));

      await expectLater(
        chartBloc.stream,
        emits(predicate<ChartState>((state) => state.pendingRowCountDialog?.rowCount == 150000)),
      );
    });

    test('CancelRowCountEvent should clear pendingRowCountDialog', () async {
      final seriesId = SeriesId(id: BigInt.one, windowId: UniqueId.next());
      final seriesInfo = SeriesInfo(
        id: seriesId,
        name: 'test',
        axes: const [],
        fields: const {},
      );

      // First set the dialog
      chartBloc.add(ShowRowCountConfirmationEvent(
        rowCount: 150000,
        series: seriesInfo,
        dayObs: '2024-01-01',
        globalQuery: null,
      ));

      // Then cancel it
      chartBloc.add(CancelRowCountEvent());

      await expectLater(
        chartBloc.stream,
        emitsInOrder([
          predicate<ChartState>((state) => state.pendingRowCountDialog?.rowCount == 150000),
          predicate<ChartState>((state) => state.pendingRowCountDialog == null),
        ]),
      );
    });

    test('ConfirmRowCountEvent should clear dialog and proceed with series addition', () async {
      final seriesId = SeriesId(id: BigInt.one, windowId: UniqueId.next());
      final seriesInfo = SeriesInfo(
        id: seriesId,
        name: 'test',
        axes: const [],
        fields: const {},
      );

      // First set the dialog
      chartBloc.add(ShowRowCountConfirmationEvent(
        rowCount: 150000,
        series: seriesInfo,
        dayObs: '2024-01-01',
        globalQuery: null,
      ));

      // Then confirm it
      chartBloc.add(ConfirmRowCountEvent());

      await expectLater(
        chartBloc.stream,
        emitsInOrder([
          predicate<ChartState>((state) => state.pendingRowCountDialog?.rowCount == 150000),
          predicate<ChartState>((state) => state.pendingRowCountDialog == null),
        ]),
      );
    });

    test('ConfirmRowCountEvent should trigger ProceedWithSeriesEvent', () async {
      final seriesId = SeriesId(id: BigInt.one, windowId: UniqueId.next());
      final seriesInfo = SeriesInfo(
        id: seriesId,
        name: 'test',
        axes: const [],
        fields: const {},
      );

      // Set up the dialog first
      chartBloc.add(ShowRowCountConfirmationEvent(
        rowCount: 150000,
        series: seriesInfo,
        dayObs: '2024-01-01',
        globalQuery: null,
      ));

      // Wait for dialog to be set
      await expectLater(
        chartBloc.stream,
        emits(predicate<ChartState>((state) => state.pendingRowCountDialog != null)),
      );

      // Now confirm and check that series is added to state
      chartBloc.add(ConfirmRowCountEvent());

      await expectLater(
        chartBloc.stream,
        emitsInOrder([
          // Dialog should be cleared
          predicate<ChartState>((state) => state.pendingRowCountDialog == null),
          // Series should be added to the chart
          predicate<ChartState>((state) => state.series.containsKey(seriesId)),
        ]),
      );
    });

    test('CancelRowCountEvent should not add series to chart', () async {
      final seriesId = SeriesId(id: BigInt.one, windowId: UniqueId.next());
      final seriesInfo = SeriesInfo(
        id: seriesId,
        name: 'test',
        axes: const [],
        fields: const {},
      );

      // Set up the dialog first
      chartBloc.add(ShowRowCountConfirmationEvent(
        rowCount: 150000,
        series: seriesInfo,
        dayObs: '2024-01-01',
        globalQuery: null,
      ));

      // Wait for dialog to be set
      await expectLater(
        chartBloc.stream,
        emits(predicate<ChartState>((state) => state.pendingRowCountDialog != null)),
      );

      // Now cancel
      chartBloc.add(CancelRowCountEvent());

      await expectLater(
        chartBloc.stream,
        emits(predicate<ChartState>(
            (state) => state.pendingRowCountDialog == null && !state.series.containsKey(seriesId))),
      );
    });

    test('Multiple dialog events should work correctly', () async {
      final seriesId1 = SeriesId(id: BigInt.one, windowId: UniqueId.next());
      final seriesInfo1 = SeriesInfo(
        id: seriesId1,
        name: 'test1',
        axes: const [],
        fields: const {},
      );

      final seriesId2 = SeriesId(id: BigInt.two, windowId: UniqueId.next());
      final seriesInfo2 = SeriesInfo(
        id: seriesId2,
        name: 'test2',
        axes: const [],
        fields: const {},
      );

      // Show first dialog and cancel
      chartBloc.add(ShowRowCountConfirmationEvent(
        rowCount: 150000,
        series: seriesInfo1,
        dayObs: '2024-01-01',
        globalQuery: null,
      ));

      chartBloc.add(CancelRowCountEvent());

      // Show second dialog and confirm
      chartBloc.add(ShowRowCountConfirmationEvent(
        rowCount: 200000,
        series: seriesInfo2,
        dayObs: '2024-01-01',
        globalQuery: null,
      ));

      chartBloc.add(ConfirmRowCountEvent());

      await expectLater(
        chartBloc.stream,
        emitsInOrder([
          // First dialog shown
          predicate<ChartState>((state) => state.pendingRowCountDialog?.series.name == 'test1'),
          // First dialog canceled
          predicate<ChartState>((state) => state.pendingRowCountDialog == null),
          // Second dialog shown
          predicate<ChartState>((state) => state.pendingRowCountDialog?.series.name == 'test2'),
          // Second dialog cleared
          predicate<ChartState>((state) => state.pendingRowCountDialog == null),
          // Only second series added
          predicate<ChartState>(
              (state) => !state.series.containsKey(seriesId1) && state.series.containsKey(seriesId2)),
        ]),
      );
    });
  });
}
