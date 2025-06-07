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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rubintv_visualization/chart/base.dart';

/// Shows a confirmation dialog for large row counts that may cause performance issues.
void showRowCountConfirmationDialog(BuildContext context, RowCountDialogInfo dialogInfo) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Large Dataset Warning'),
        content: Text(
          'This query will return ${dialogInfo.rowCount.toStringAsFixed(0)} rows. '
          'This may cause performance issues or slow rendering.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<ChartBloc>().add(CancelRowCountEvent());
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<ChartBloc>().add(ConfirmRowCountEvent());
            },
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );
}
