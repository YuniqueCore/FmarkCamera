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
    this.overlayData,
    this.thumbnailPath,
    this.thumbnailData,
    this.thumbnailUpdatedAt,
    this.mediaDataBase64,
  });

  final String id;
  final String mediaPath;
  final WatermarkMediaType mediaType;
  final DateTime capturedAt;
  final String profileId;
  final WatermarkCanvasSize? canvasSize;
  final double? previewRatio;
  final String? overlayPath;
  final String? overlayData;
  final String? thumbnailPath;
  final String? thumbnailData;
  final DateTime? thumbnailUpdatedAt;
  final String? mediaDataBase64;

  WatermarkProject copyWith({
    String? mediaPath,
    WatermarkMediaType? mediaType,
    DateTime? capturedAt,
    String? profileId,
    WatermarkCanvasSize? canvasSize,
    double? previewRatio,
    String? overlayPath,
    String? overlayData,
    String? thumbnailPath,
    String? thumbnailData,
    DateTime? thumbnailUpdatedAt,
    String? mediaDataBase64,
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
      overlayData: overlayData ?? this.overlayData,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailData: thumbnailData ?? this.thumbnailData,
      thumbnailUpdatedAt: thumbnailUpdatedAt ?? this.thumbnailUpdatedAt,
      mediaDataBase64: mediaDataBase64 ?? this.mediaDataBase64,
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
        'overlayData': overlayData,
        'thumbnailPath': thumbnailPath,
        'thumbnailData': thumbnailData,
        'thumbnailUpdatedAt': thumbnailUpdatedAt?.toIso8601String(),
        'mediaDataBase64': mediaDataBase64,
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
      overlayData: json['overlayData'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
      thumbnailData: json['thumbnailData'] as String?,
      thumbnailUpdatedAt: json['thumbnailUpdatedAt'] == null
          ? null
          : DateTime.tryParse(json['thumbnailUpdatedAt'] as String),
      mediaDataBase64: json['mediaDataBase64'] as String?,
    );
  }
}
