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

  bool approximatelyEquals(
    CameraResolutionInfo other, {
    double tolerance = 1.0,
  }) {
    final directMatch = (width - other.width).abs() <= tolerance &&
        (height - other.height).abs() <= tolerance;
    if (directMatch) {
      return true;
    }
    final swappedMatch = (width - other.height).abs() <= tolerance &&
        (height - other.width).abs() <= tolerance;
    return swappedMatch;
  }

  CameraResolutionInfo toPortrait() {
    if (height >= width) {
      return this;
    }
    return CameraResolutionInfo(width: height, height: width);
  }

  CameraResolutionInfo toLandscape() {
    if (width >= height) {
      return this;
    }
    return CameraResolutionInfo(width: height, height: width);
  }

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

class CameraResolutionSelection {
  const CameraResolutionSelection({
    required this.resolution,
    required this.preset,
    this.cameraId,
    this.lensFacing,
  });

  final CameraResolutionInfo resolution;
  final ResolutionPreset preset;
  final String? cameraId;
  final String? lensFacing;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'resolution': resolution.toJson(),
        'preset': preset.name,
        'cameraId': cameraId,
        'lensFacing': lensFacing,
      };

  factory CameraResolutionSelection.fromJson(Map<String, dynamic> json) {
    final resolutionJson = json['resolution'];
    if (resolutionJson is! Map<String, dynamic>) {
      throw ArgumentError('resolution missing from selection json');
    }
    final presetName = json['preset'] as String?;
    final preset = ResolutionPreset.values.firstWhere(
      (item) => item.name == presetName,
      orElse: () => ResolutionPreset.high,
    );
    return CameraResolutionSelection(
      resolution: CameraResolutionInfo.fromJson(resolutionJson),
      preset: preset,
      cameraId: json['cameraId'] as String?,
      lensFacing: json['lensFacing'] as String?,
    );
  }

  CameraResolutionSelection copyWith({
    CameraResolutionInfo? resolution,
    ResolutionPreset? preset,
    String? cameraId,
    String? lensFacing,
  }) {
    return CameraResolutionSelection(
      resolution: resolution ?? this.resolution,
      preset: preset ?? this.preset,
      cameraId: cameraId ?? this.cameraId,
      lensFacing: lensFacing ?? this.lensFacing,
    );
  }

  bool matchesResolution(CameraResolutionInfo info, {double tolerance = 1.0}) {
    return resolution.approximatelyEquals(info, tolerance: tolerance);
  }
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
