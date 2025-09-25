import 'package:flutter/material.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';

import 'package:fmark_camera/src/presentation/widgets/watermark_element_widget.dart';

typedef WatermarkElementChanged = void Function(WatermarkElement element);
typedef WatermarkElementSelected = void Function(String? elementId);
typedef WatermarkElementDeleted = void Function(String elementId);

class WatermarkCanvasView extends StatelessWidget {
  const WatermarkCanvasView({
    super.key,
    required this.elements,
    required this.contextData,
    required this.canvasSize,
  });

  final List<WatermarkElement> elements;
  final WatermarkContext contextData;
  final WatermarkCanvasSize canvasSize;

  @override
  Widget build(BuildContext context) {
    return _CanvasLayout(
      canvasSize: canvasSize,
      builder: (size) {
        final ordered = [...elements]
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
        return Stack(
          children: ordered
              .map(
                (element) => WatermarkElementView(
                  key: ValueKey(element.id),
                  element: element,
                  contextData: contextData,
                  canvasSize: canvasSize,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class EditableWatermarkCanvas extends StatelessWidget {
  const EditableWatermarkCanvas({
    super.key,
    required this.elements,
    required this.contextData,
    required this.canvasSize,
    required this.selectedElementId,
    required this.onElementSelected,
    required this.onElementChanged,
    this.onElementDeleted,
  });

  final List<WatermarkElement> elements;
  final WatermarkContext contextData;
  final WatermarkCanvasSize canvasSize;
  final String? selectedElementId;
  final WatermarkElementSelected onElementSelected;
  final WatermarkElementChanged onElementChanged;
  final WatermarkElementDeleted? onElementDeleted;

  @override
  Widget build(BuildContext context) {
    return _CanvasLayout(
      canvasSize: canvasSize,
      builder: (size) {
        final ordered = [...elements]
          ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
        return Stack(
          children: ordered
              .map(
                (element) => EditableWatermarkElement(
                  key: ValueKey(element.id),
                  element: element,
                  contextData: contextData,
                  canvasSize: canvasSize,
                  selected: element.id == selectedElementId,
                  onSelected: () => onElementSelected(element.id),
                  onDelete: onElementDeleted == null
                      ? null
                      : () => onElementDeleted!(element.id),
                  onTransform: (transform) =>
                      onElementChanged(element.copyWith(transform: transform)),
                  isLocked: element.isLocked,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _CanvasLayout extends StatelessWidget {
  const _CanvasLayout({
    required this.canvasSize,
    required this.builder,
  });

  final WatermarkCanvasSize canvasSize;
  final Widget Function(Size size) builder;

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
        final size = Size(width, height);
        return Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: builder(size),
          ),
        );
      },
    );
  }
}
