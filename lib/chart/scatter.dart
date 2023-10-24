import 'package:flutter/material.dart';
import 'package:rubintv_visualization/id.dart';
import 'package:rubintv_visualization/state/workspace.dart';
import 'package:rubintv_visualization/workspace/window.dart';

class ScatterChart extends Window {
  final Map<String, List> data;
  ScatterChart(
      {required super.id,
      required super.offset,
      required super.size,
      super.title,
      required this.data});

  @override
  Widget build(BuildContext context) {
    return Container();
  }

  @override
  ScatterChart copyWith(
      {UniqueId? id,
      Offset? offset,
      Size? size,
      String? title,
      Map<String, List>? data}) {
    return ScatterChart(
        id: id ?? this.id,
        offset: offset ?? this.offset,
        size: size ?? this.size,
        title: title ?? this.title,
        data: data ?? this.data);
  }

  @override
  Widget createWidget(BuildContext context) {
    return SizedBox(
      height: size.height,
      width: size.width,
      child: Container(),
    );
  }

  @override
  Widget? createToolbar(BuildContext context) {
    WorkspaceViewerState workspace = WorkspaceViewer.of(context);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.redAccent,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () {
          workspace.dispatch(RemoveWindowAction(this));
        },
      ),
    );
  }
}
