import 'watermark_media_type.dart';

class WatermarkProject {
  const WatermarkProject({
    required this.id,
    required this.mediaPath,
    required this.mediaType,
    required this.capturedAt,
    required this.profileId,
    this.overlayPath,
    this.thumbnailPath,
  });

  final String id;
  final String mediaPath;
  final WatermarkMediaType mediaType;
  final DateTime capturedAt;
  final String profileId;
  final String? overlayPath;
  final String? thumbnailPath;

  WatermarkProject copyWith({
    String? mediaPath,
    WatermarkMediaType? mediaType,
    DateTime? capturedAt,
    String? profileId,
    String? overlayPath,
    String? thumbnailPath,
  }) {
    return WatermarkProject(
      id: id,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      capturedAt: capturedAt ?? this.capturedAt,
      profileId: profileId ?? this.profileId,
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
        'overlayPath': overlayPath,
        'thumbnailPath': thumbnailPath,
      };

  factory WatermarkProject.fromJson(Map<String, dynamic> json) {
    final typeName = json['mediaType'] as String? ?? WatermarkMediaType.photo.name;
    final mediaType = WatermarkMediaType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => WatermarkMediaType.photo,
    );
    return WatermarkProject(
      id: json['id'] as String? ?? '',
      mediaPath: json['mediaPath'] as String? ?? '',
      mediaType: mediaType,
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? '') ?? DateTime.now(),
      profileId: json['profileId'] as String? ?? '',
      overlayPath: json['overlayPath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }
}
