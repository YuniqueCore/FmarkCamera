import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';

class WatermarkProject {
  const WatermarkProject({
    required this.id,
    required this.mediaPath,
    required this.mediaType,
    required this.capturedAt,
    required this.profileId,
    this.canvasSize,
    this.previewRatio,
    this.overlayPath,
    this.thumbnailPath,
  });

  final String id;
  final String mediaPath;
  final WatermarkMediaType mediaType;
  final DateTime capturedAt;
  final String profileId;
  final WatermarkCanvasSize? canvasSize;
  final double? previewRatio;
  final String? overlayPath;
  final String? thumbnailPath;

  WatermarkProject copyWith({
    String? mediaPath,
    WatermarkMediaType? mediaType,
    DateTime? capturedAt,
    String? profileId,
    WatermarkCanvasSize? canvasSize,
    double? previewRatio,
    String? overlayPath,
    String? thumbnailPath,
  }) {
    return WatermarkProject(
      id: id,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      capturedAt: capturedAt ?? this.capturedAt,
      profileId: profileId ?? this.profileId,
      canvasSize: canvasSize ?? this.canvasSize,
      previewRatio: previewRatio ?? this.previewRatio,
      overlayPath: overlayPath ?? this.overlayPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'mediaPath': mediaPath,
        'mediaType': mediaType.name,
        'capturedAt': capturedAt.toIso8601String(),
        'profileId': profileId,
        'canvasSize': canvasSize?.toJson(),
        'previewRatio': previewRatio,
        'overlayPath': overlayPath,
        'thumbnailPath': thumbnailPath,
      };

  factory WatermarkProject.fromJson(Map<String, dynamic> json) {
    final typeName =
        json['mediaType'] as String? ?? WatermarkMediaType.photo.name;
    final mediaType = WatermarkMediaType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => WatermarkMediaType.photo,
    );
    return WatermarkProject(
      id: json['id'] as String? ?? '',
      mediaPath: json['mediaPath'] as String? ?? '',
      mediaType: mediaType,
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ??
          DateTime.now(),
      profileId: json['profileId'] as String? ?? '',
      canvasSize: json['canvasSize'] == null
          ? null
          : WatermarkCanvasSize.fromJson(
              json['canvasSize'] as Map<String, dynamic>,
            ),
      previewRatio: (json['previewRatio'] as num?)?.toDouble(),
      overlayPath: json['overlayPath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }
}
