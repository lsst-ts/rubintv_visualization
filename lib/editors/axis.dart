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
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';

/// An editor used to modify the properties of an axis.
class AxisEditor extends StatefulWidget {
  /// The information for the axis to edit.
  final ChartAxisInfo axisInfo;

  /// The [ChartBloc] that contains the axis.
  final ChartBloc chartBloc;

  const AxisEditor({
    super.key,
    required this.axisInfo,
    required this.chartBloc,
  });

  @override
  AxisEditorState createState() => AxisEditorState();
}

/// The state of an [AxisEditor].
class AxisEditorState extends State<AxisEditor> {
  /// The key used to validate the form.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// The controller used to edit the label of the axis.
  late TextEditingController _labelController;

  /// Whether the axis is inverted.
  late bool _isInverted;

  /// Initialize the state of the editor.
  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.axisInfo.label);
    _isInverted = widget.axisInfo.isInverted;
  }

  /// Dispose of the controller when the editor is closed.
  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: "Label",
                ),
              ),
              CheckboxListTile(
                title: const Text("Invert axis"),
                value: _isInverted,
                onChanged: (value) {
                  setState(() {
                    _isInverted = value!;
                  });
                },
              ),
              Row(children: [
                const Spacer(),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.cancel, color: Colors.red),
                ),
                IconButton(
                  onPressed: () {
                    ChartAxisInfo value = ChartAxisInfo(
                      label: _labelController.text,
                      axisId: widget.axisInfo.axisId,
                      isInverted: _isInverted,
                    );
                    widget.chartBloc.add(UpdateAxisInfoEvent(value));
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
