import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/models/watermark_project.dart';
import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_transform.dart';
import 'package:fmark_camera/src/domain/models/watermark_text_style.dart';

void main() {
  test('WatermarkProject thumbnailData roundtrip', () {
    final project = WatermarkProject(
      id: 'p1',
      mediaPath: '/tmp/a.jpg',
      mediaType: WatermarkMediaType.photo,
      capturedAt: DateTime(2024, 1, 1),
      profileId: 'profile-1',
      thumbnailData: base64Encode([1, 2, 3]),
      thumbnailUpdatedAt: DateTime(2024, 1, 2),
    );
    final json = project.toJson();
    final parsed = WatermarkProject.fromJson(json);
    expect(parsed.thumbnailData, project.thumbnailData);
    expect(parsed.thumbnailUpdatedAt?.toIso8601String(),
        project.thumbnailUpdatedAt?.toIso8601String());
  });

  test('WatermarkProfile updatedAt drives invalidation decision (model exists)',
      () {
    final profile = WatermarkProfile(
      id: 'p',
      name: 'n',
      elements: const [
        WatermarkElement(
          id: 'e1',
          type: WatermarkElementType.text,
          transform: WatermarkTransform(
            position: Offset(0.5, 0.5),
            scale: 1,
            rotation: 0,
          ),
          textStyle: WatermarkTextStyle(fontSize: 12),
        ),
      ],
      updatedAt: DateTime(2025, 1, 2),
    );
    expect(profile.updatedAt, DateTime(2025, 1, 2));
  });
}
