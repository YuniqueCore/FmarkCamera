import 'package:flutter/widgets.dart';

import 'package:fmark_camera/src/domain/models/watermark_element.dart';

typedef WatermarkElementList = List<WatermarkElement>;

class WatermarkProfile {
  const WatermarkProfile({
    required this.id,
    required this.name,
    required this.elements,
    this.isDefault = false,
    this.canvasSize,
    this.updatedAt,
  });

  final String id;
  final String name;
  final WatermarkElementList elements;
  final bool isDefault;
  final WatermarkCanvasSize? canvasSize;
  final DateTime? updatedAt;

  WatermarkProfile copyWith({
    String? name,
    WatermarkElementList? elements,
    bool? isDefault,
    WatermarkCanvasSize? canvasSize,
    DateTime? updatedAt,
  }) {
    return WatermarkProfile(
      id: id,
      name: name ?? this.name,
      elements: elements ?? this.elements,
      isDefault: isDefault ?? this.isDefault,
      canvasSize: canvasSize ?? this.canvasSize,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'elements': elements.map((element) => element.toJson()).toList(),
        'isDefault': isDefault,
        'canvasSize': canvasSize?.toJson(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory WatermarkProfile.fromJson(Map<String, dynamic> json) {
    final elementsJson = json['elements'] as List<dynamic>? ?? <dynamic>[];
    return WatermarkProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed',
      elements: elementsJson
          .map((elementJson) => WatermarkElement.fromJson(
                elementJson as Map<String, dynamic>,
              ))
          .toList(),
      isDefault: json['isDefault'] as bool? ?? false,
      canvasSize: json['canvasSize'] == null
          ? null
          : WatermarkCanvasSize.fromJson(
              json['canvasSize'] as Map<String, dynamic>,
            ),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }
}

class WatermarkCanvasSize {
  const WatermarkCanvasSize({
    required this.width,
    required this.height,
    this.pixelRatio = 1,
  });

  final double width;
  final double height;
  final double pixelRatio;

  factory WatermarkCanvasSize.fromJson(Map<String, dynamic> json) {
    return WatermarkCanvasSize(
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      pixelRatio: (json['pixelRatio'] as num?)?.toDouble() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'width': width,
        'height': height,
        'pixelRatio': pixelRatio,
      };

  WatermarkCanvasSize copyWith({
    double? width,
    double? height,
    double? pixelRatio,
  }) {
    return WatermarkCanvasSize(
      width: width ?? this.width,
      height: height ?? this.height,
      pixelRatio: pixelRatio ?? this.pixelRatio,
    );
  }

  Size toSize() => Size(width, height);
}
