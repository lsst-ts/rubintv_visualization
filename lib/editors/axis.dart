import 'package:flutter/material.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/chart/base.dart';

class AxisEditor extends StatefulWidget {
  final ChartAxisInfo axisInfo;
  final ChartBloc chartBloc;

  const AxisEditor({
    super.key,
    required this.axisInfo,
    required this.chartBloc,
  });

  @override
  AxisEditorState createState() => AxisEditorState();
}

class AxisEditorState extends State<AxisEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late bool _isInverted;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.axisInfo.label);
    _isInverted = widget.axisInfo.isInverted;
  }

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
