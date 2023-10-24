/*import 'package:flutter/material.dart';
import 'package:rubin_chart/rubin_chart.dart';
import 'package:rubintv_visualization/state/action.dart';
import 'package:rubintv_visualization/state/theme.dart';
import 'package:rubintv_visualization/workspace/data.dart';

/// Update the [PlotAxis] for a given [Chart].
class AxisUpdate extends UiAction {
  final Chart chart;
  final PlotAxis newAxis;
  final int axisIndex;

  const AxisUpdate({
    required this.chart,
    required this.newAxis,
    required this.axisIndex,
  });
}

/// Edit parameters for a [PlotAxis].
class AxisEditor extends StatefulWidget {
  final AppTheme theme;
  final Chart info;
  final PlotAxis? axis;
  final DataCenter dataCenter;
  final DispatchAction dispatch;
  final String title;
  final int axisIndex;
  final AxisOrientation orientation;
  final Bounds dataBounds;

  const AxisEditor({
    super.key,
    required this.title,
    required this.theme,
    required this.info,
    required this.axis,
    required this.dataCenter,
    required this.dispatch,
    required this.axisIndex,
    required this.orientation,
    required this.dataBounds,
  });

  @override
  AxisEditorState createState() => AxisEditorState();
}

/// [State] for an [AxisEditor].
class AxisEditorState extends State<AxisEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  AppTheme get theme => widget.theme;
  late PlotAxis axis;
  DataCenter get dataCenter => widget.dataCenter;
  RangeValues get _currentRangeValues =>
      RangeValues(axis.bounds.min.toDouble(), axis.bounds.max.toDouble());

  TextEditingController columnMinController = TextEditingController();
  TextEditingController columnMaxController = TextEditingController();
  Bounds get columnBounds => widget.dataBounds;
  Bounds get _rangeBounds {
    double min = axis.bounds.min.toDouble();
    double max = axis.bounds.max.toDouble();
    if (columnBounds.min < min) {
      min = columnBounds.min.toDouble();
    }
    if (columnBounds.max > max) {
      max = columnBounds.max.toDouble();
    }
    return Bounds(min, max);
  }

  final MaterialStateProperty<Icon?> thumbIcon =
      MaterialStateProperty.resolveWith<Icon?>(
    (Set<MaterialState> states) {
      if (states.contains(MaterialState.selected)) {
        return const Icon(Icons.check);
      }
      return const Icon(Icons.close);
    },
  );

  IconData get _icon => axis.boundsFixed ? Icons.lock : Icons.lock_open;

  Color get _iconColor => axis.boundsFixed
      ? theme.themeData.colorScheme.secondary
      : theme.themeData.colorScheme.tertiary;

  @override
  void initState() {
    super.initState();
    axis = widget.axis!.copy();
    columnMinController.text = "${_rangeBounds.min}";
    columnMaxController.text = "${_rangeBounds.max}";
  }

  @override
  Widget build(BuildContext context) {
    final List<DropdownMenuItem<Mapping>> mappingEntries = [
      const DropdownMenuItem(value: LinearMapping(), child: Text("linear")),
      const DropdownMenuItem(value: Log10Mapping(), child: Text("log")),
    ];

    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 400,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Text(widget.title,
                      style: widget.theme.chartTheme.editorTitleStyle),
                ),
                const SizedBox(
                  height: 20,
                ),
                TextFormField(
                  initialValue: axis.label,
                  onChanged: (String? value) {
                    axis = axis.copyWith(label: value);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    IntrinsicWidth(
                      child: DropdownButtonFormField<Mapping>(
                          decoration: widget.theme.queryTextDecoration.copyWith(
                            labelText: "scale",
                          ),
                          value: axis.mapping,
                          items: mappingEntries,
                          onChanged: (Mapping? value) {
                            if (value != null) {
                              axis = axis.copyWith(mapping: value);
                            }
                          }),
                    ),
                    const Spacer(),
                    const Text("invert"),
                    Switch(
                      thumbIcon: thumbIcon,
                      value: axis.isInverted,
                      onChanged: (bool value) {
                        setState(() {
                          axis = axis.copyWith(isInverted: value);
                        });
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(_icon, color: _iconColor),
                      onPressed: () {
                        setState(() {
                          axis = axis.copyWith(boundsFixed: !axis.boundsFixed);
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(children: [
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: columnMinController,
                      onChanged: (String? value) {
                        if (value != null) {
                          double? min = double.tryParse(value);
                          if (min != null) {
                            setState(() {
                              axis = axis.copyWith(
                                  bounds: Bounds(min, axis.bounds.max));
                            });
                          }
                        }
                      },
                    ),
                  ),
                  RangeSlider(
                    values: _currentRangeValues,
                    min: _rangeBounds.min.toDouble(),
                    max: _rangeBounds.max.toDouble(),
                    onChanged: (RangeValues values) {
                      setState(() {
                        axis = axis.copyWith(
                            bounds: Bounds(values.start, values.end));
                        columnMinController.text =
                            axis.bounds.min.toStringAsPrecision(7);
                        columnMaxController.text =
                            axis.bounds.max.toStringAsPrecision(7);
                      });
                    },
                  ),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: columnMaxController,
                      onChanged: (String? value) {
                        if (value != null) {
                          double? max = double.tryParse(value);
                          if (max != null) {
                            setState(() {
                              axis = axis.copyWith(
                                  bounds: Bounds(axis.bounds.min, max));
                            });
                          }
                        }
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.cancel, color: Colors.red),
                    ),
                    IconButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          widget.dispatch(AxisUpdate(
                            chart: widget.info,
                            newAxis: axis,
                            axisIndex: widget.axisIndex,
                          ));
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                    ),
                  ],
                ),
              ]),
        ),
      ),
    );
  }
}
*/