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
  });
}
