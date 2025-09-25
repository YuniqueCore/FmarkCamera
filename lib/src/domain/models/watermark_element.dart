import 'package:flutter/material.dart';

import 'package:fmark_camera/src/domain/models/watermark_element_payload.dart';
import 'package:fmark_camera/src/domain/models/watermark_text_style.dart';
import 'package:fmark_camera/src/domain/models/watermark_transform.dart';

enum WatermarkElementType { text, time, location, weather, image }

class WatermarkElement {
  const WatermarkElement({
    required this.id,
    required this.type,
    required this.transform,
    this.opacity = 1.0,
    this.textStyle,
    this.payload = const WatermarkElementPayload(),
    this.zIndex = 0,
    this.isLocked = false,
  });

  final String id;
  final WatermarkElementType type;
  final WatermarkTransform transform;
  final double opacity;
  final WatermarkTextStyle? textStyle;
  final WatermarkElementPayload payload;
  final int zIndex;
  final bool isLocked;

  WatermarkElement copyWith({
    WatermarkTransform? transform,
    double? opacity,
    WatermarkTextStyle? textStyle,
    WatermarkElementPayload? payload,
    int? zIndex,
    bool? isLocked,
  }) {
    return WatermarkElement(
      id: id,
      type: type,
      transform: transform ?? this.transform,
      opacity: opacity ?? this.opacity,
      textStyle: textStyle ?? this.textStyle,
      payload: payload ?? this.payload,
      zIndex: zIndex ?? this.zIndex,
      isLocked: isLocked ?? this.isLocked,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'transform': transform.toJson(),
        'opacity': opacity,
        'textStyle': textStyle?.toJson(),
        'payload': payload.toJson(),
        'zIndex': zIndex,
        'isLocked': isLocked,
      };

  factory WatermarkElement.fromJson(Map<String, dynamic> json) {
    final typeName = json['type'] as String? ?? WatermarkElementType.text.name;
    final matchedType = WatermarkElementType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => WatermarkElementType.text,
    );
    final textStyleJson = json['textStyle'] as Map<String, dynamic>?;
    return WatermarkElement(
      id: json['id'] as String? ?? UniqueKey().toString(),
      type: matchedType,
      transform: WatermarkTransform.fromJson(
        json['transform'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      textStyle: textStyleJson == null
          ? null
          : WatermarkTextStyle.fromJson(textStyleJson),
      payload: WatermarkElementPayload.fromJson(
        json['payload'] as Map<String, dynamic>? ?? <String, dynamic>{},
      ),
      zIndex: json['zIndex'] as int? ?? 0,
      isLocked: json['isLocked'] as bool? ?? false,
    );
  }
}
