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
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:rubintv_visualization/focal_plane/slider.dart';

/// A dialog that allows the user to pick a color and value for a color stop.
class ColorPickerDialog extends StatefulWidget {
  /// The initial color stop to edit.
  final ColorbarStop initialStop;

  /// The controller used to update the color stops.
  final ColorbarController controller;

  const ColorPickerDialog({
    super.key,
    required this.initialStop,
    required this.controller,
  });

  @override
  ColorPickerDialogState createState() => ColorPickerDialogState();
}

/// The state of the [ColorPickerDialog].
class ColorPickerDialogState extends State<ColorPickerDialog> {
  /// The color of the stop.
  late Color _color;

  /// The text controller for the value associated with the selected color.
  late TextEditingController _textController;

  /// Initialzie the color and text controller.
  @override
  void initState() {
    super.initState();
    _color = widget.initialStop.color;
    _textController = TextEditingController(text: widget.initialStop.value.toString());
  }

  /// Dispose of the text controller.
  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Center(child: Text("Color")),
      content: Column(
        children: [
          HueRingPicker(
            pickerColor: _color,
            onColorChanged: (Color color) {
              setState(() {
                _color = color;
              });
            },
            enableAlpha: false,
            displayThumbColor: true,
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: const InputDecoration(
              labelText: "Value",
              border: OutlineInputBorder(),
            ),
            controller: _textController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (String value) {
              // No need to update state here
            },
          ),
          const SizedBox(height: 20),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  if (widget.controller.stopCount <= 2) {
                    return;
                  }
                  widget.controller.removeStop(widget.initialStop.id);
                  Navigator.of(context).pop();
                },
                child: const Text("Remove"),
              ),
              TextButton(
                onPressed: () {
                  double? newValue = double.tryParse(_textController.text);
                  if (newValue != null) {
                    widget.controller.updateStop(widget.initialStop.id, newValue, _color);
                    Navigator.of(context).pop();
                  } else {
                    // Show an error message or handle invalid input
                  }
                },
                child: const Text("Ok"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
