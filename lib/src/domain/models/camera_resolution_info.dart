import 'dart:ui';

import 'package:camera/camera.dart';

enum CameraCaptureMode { photo, video }

class CameraResolutionInfo {
  const CameraResolutionInfo({required this.width, required this.height});

  final double width;
  final double height;

  bool get isValid => width > 0 && height > 0;
  double get aspectRatio => height == 0 ? 0 : width / height;
  double get pixelCount => width * height;

  Size toSize() => Size(width, height);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'width': width,
        'height': height,
      };

  factory CameraResolutionInfo.fromJson(Map<String, dynamic> json) {
    return CameraResolutionInfo(
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
    );
  }

  @override
  int get hashCode => Object.hash(width, height);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! CameraResolutionInfo) {
      return false;
    }
    return (width - other.width).abs() < 0.5 &&
        (height - other.height).abs() < 0.5;
  }

  @override
  String toString() =>
      'CameraResolutionInfo(${width.toStringAsFixed(0)}x${height.toStringAsFixed(0)})';
}

String resolutionPresetLabel(ResolutionPreset preset) {
  switch (preset) {
    case ResolutionPreset.low:
      return 'Low (288p)';
    case ResolutionPreset.medium:
      return 'Medium (480p)';
    case ResolutionPreset.high:
      return 'High (720p)';
    case ResolutionPreset.veryHigh:
      return 'Very High (1080p)';
    case ResolutionPreset.ultraHigh:
      return 'Ultra High (2160p)';
    case ResolutionPreset.max:
      return 'Max (设备最高)';
  }
}
