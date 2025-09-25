import 'package:flutter/widgets.dart';

class WatermarkTransform {
  const WatermarkTransform({
    required this.position,
    required this.scale,
    required this.rotation,
  });

  final Offset position;
  final double scale;
  final double rotation;

  WatermarkTransform copyWith({
    Offset? position,
    double? scale,
    double? rotation,
  }) {
    return WatermarkTransform(
      position: position ?? this.position,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'position': <String, double>{
          'dx': position.dx,
          'dy': position.dy,
        },
        'scale': scale,
        'rotation': rotation,
      };

  factory WatermarkTransform.fromJson(Map<String, dynamic> json) {
    final positionJson = json['position'] as Map<String, dynamic>?;
    return WatermarkTransform(
      position: Offset(
        (positionJson?['dx'] as num?)?.toDouble() ?? 0.5,
        (positionJson?['dy'] as num?)?.toDouble() ?? 0.5,
      ),
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
