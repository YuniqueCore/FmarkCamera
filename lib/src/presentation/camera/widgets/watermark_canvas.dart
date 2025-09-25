import 'package:flutter/material.dart';

import '../../../domain/models/watermark_context.dart';
import '../../../domain/models/watermark_element.dart';
import '../../../domain/models/watermark_transform.dart';
import 'watermark_element_widget.dart';

typedef ElementChanged = void Function(WatermarkElement element);
typedef ElementSelected = void Function(String? elementId);

typedef ElementDeleted = void Function(String elementId);

class WatermarkCanvas extends StatelessWidget {
  const WatermarkCanvas({
    super.key,
    required this.elements,
    required this.contextData,
    required this.onElementChanged,
    required this.onElementSelected,
    required this.selectedElementId,
    required this.isEditing,
    this.onElementDeleted,
  });

  final List<WatermarkElement> elements;
  final WatermarkContext contextData;
  final ElementChanged onElementChanged;
  final ElementSelected onElementSelected;
  final ElementDeleted? onElementDeleted;
  final String? selectedElementId;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final orderedElements = [...elements]..sort((a, b) => a.zIndex.compareTo(b.zIndex));
        return Stack(
          children: orderedElements.map((element) {
            return WatermarkElementWidget(
              key: ValueKey(element.id),
              element: element,
              contextData: contextData,
              canvasSize: size,
              selected: selectedElementId == element.id,
              isEditing: isEditing,
              onSelected: () => onElementSelected(element.id),
              onTransform: (transform) {
                onElementChanged(element.copyWith(transform: transform));
              },
              onOpacityChanged: (opacity) {
                onElementChanged(element.copyWith(opacity: opacity));
              },
              onDelete: onElementDeleted == null ? null : () => onElementDeleted!(element.id),
            );
          }).toList(),
        );
      },
    );
  }
}
