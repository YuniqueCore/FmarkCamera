import 'package:flutter/material.dart';

import 'package:fmark_camera/src/domain/models/watermark_profile.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/presentation/camera/widgets/watermark_element_widget.dart';

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
    required this.canvasSize,
    this.onElementDeleted,
  });

  final List<WatermarkElement> elements;
  final WatermarkContext contextData;
  final ElementChanged onElementChanged;
  final ElementSelected onElementSelected;
  final ElementDeleted? onElementDeleted;
  final String? selectedElementId;
  final bool isEditing;
  final WatermarkCanvasSize canvasSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fallbackWidth = canvasSize.width > 0 ? canvasSize.width : 1080.0;
        final fallbackHeight =
            canvasSize.height > 0 ? canvasSize.height : 1920.0;
        double width = constraints.maxWidth;
        if (width.isInfinite || width <= 0) {
          width = fallbackWidth;
        }
        double height = width / fallbackWidth * fallbackHeight;
        final maxHeight = constraints.maxHeight;
        if (!maxHeight.isInfinite && maxHeight > 0 && height > maxHeight) {
          final scale = maxHeight / height;
          height = maxHeight;
          width = width * scale;
        }
        final orderedElements = [...elements]
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: orderedElements.map((element) {
                return WatermarkElementWidget(
                  key: ValueKey(element.id),
                  element: element,
                  contextData: contextData,
                  canvasSize: canvasSize,
                  selected: selectedElementId == element.id,
                  isEditing: isEditing,
                  onSelected: () => onElementSelected(element.id),
                  onTransform: (transform) {
                    onElementChanged(element.copyWith(transform: transform));
                  },
                  onOpacityChanged: (opacity) {
                    onElementChanged(element.copyWith(opacity: opacity));
                  },
                  onDelete: onElementDeleted == null
                      ? null
                      : () => onElementDeleted!(element.id),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
