import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:rubintv_visualization/focal_plane/slider.dart';

class ColorPickerDialog extends StatefulWidget {
  final ColorbarStop initialStop;
  final ColorbarController controller;

  const ColorPickerDialog({
    super.key,
    required this.initialStop,
    required this.controller,
  });

  @override
  ColorPickerDialogState createState() => ColorPickerDialogState();
}

class ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _color;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _color = widget.initialStop.color;
    _textController = TextEditingController(text: widget.initialStop.value.toString());
  }

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
