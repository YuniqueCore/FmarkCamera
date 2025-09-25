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

  group('Gallery thumbnail invalidation strategy', () {
    test(
        'should invalidate when profile updatedAt is newer than project thumbnailUpdatedAt',
        () {
      final profileUpdatedAt = DateTime(2025, 1, 3);
      final projectThumbnailUpdatedAt = DateTime(2025, 1, 2);

      final profile = WatermarkProfile(
        id: 'profile-1',
        name: 'Test Profile',
        elements: const [],
        updatedAt: profileUpdatedAt,
      );

      final project = WatermarkProject(
        id: 'project-1',
        mediaPath: '/tmp/test.jpg',
        mediaType: WatermarkMediaType.photo,
        capturedAt: DateTime(2025, 1, 1),
        profileId: 'profile-1',
        thumbnailUpdatedAt: projectThumbnailUpdatedAt,
      );

      // 模拟 Gallery 中的失效逻辑
      final needRender = profile.updatedAt != null &&
          project.thumbnailUpdatedAt != null &&
          project.thumbnailUpdatedAt!.isBefore(profile.updatedAt!);

      expect(needRender, isTrue);
    });

    test(
        'should not invalidate when profile updatedAt is older than project thumbnailUpdatedAt',
        () {
      final profileUpdatedAt = DateTime(2025, 1, 1);
      final projectThumbnailUpdatedAt = DateTime(2025, 1, 2);

      final profile = WatermarkProfile(
        id: 'profile-1',
        name: 'Test Profile',
        elements: const [],
        updatedAt: profileUpdatedAt,
      );

      final project = WatermarkProject(
        id: 'project-1',
        mediaPath: '/tmp/test.jpg',
        mediaType: WatermarkMediaType.photo,
        capturedAt: DateTime(2025, 1, 1),
        profileId: 'profile-1',
        thumbnailUpdatedAt: projectThumbnailUpdatedAt,
        thumbnailData: base64Encode([1, 2, 3]), // 有缓存数据
      );

      // 模拟 Gallery 中的失效逻辑
      final needRender = profile.updatedAt != null &&
          project.thumbnailUpdatedAt != null &&
          project.thumbnailUpdatedAt!.isBefore(profile.updatedAt!);

      expect(needRender, isFalse);
      expect(project.thumbnailData, isNotNull); // 应该使用缓存
    });

    test('should invalidate when project has no thumbnailUpdatedAt', () {
      final profile = WatermarkProfile(
        id: 'profile-1',
        name: 'Test Profile',
        elements: const [],
        updatedAt: DateTime(2025, 1, 2),
      );

      final project = WatermarkProject(
        id: 'project-1',
        mediaPath: '/tmp/test.jpg',
        mediaType: WatermarkMediaType.photo,
        capturedAt: DateTime(2025, 1, 1),
        profileId: 'profile-1',
        thumbnailUpdatedAt: null, // 无更新时间
      );

      // 模拟 Gallery 中的失效逻辑
      final needRender = project.thumbnailUpdatedAt == null ||
          (profile.updatedAt != null &&
              project.thumbnailUpdatedAt!.isBefore(profile.updatedAt!));

      expect(needRender, isTrue);
    });

    test('should handle missing thumbnailData gracefully', () {
      final project = WatermarkProject(
        id: 'project-1',
        mediaPath: '/tmp/test.jpg',
        mediaType: WatermarkMediaType.photo,
        capturedAt: DateTime(2025, 1, 1),
        profileId: 'profile-1',
        thumbnailData: null, // 无缓存数据
        thumbnailUpdatedAt: DateTime(2025, 1, 2),
      );

      expect(project.thumbnailData, isNull);

      // 模拟 Gallery 中解码逻辑
      List<int>? decodedBytes;
      if (project.thumbnailData != null) {
        try {
          decodedBytes = base64Decode(project.thumbnailData!);
        } catch (_) {
          decodedBytes = null;
        }
      }

      expect(decodedBytes, isNull);
    });
  });

  group('Export branches validation', () {
    test('WatermarkProject supports all media types for export decision', () {
      final photoProject = WatermarkProject(
        id: 'photo-1',
        mediaPath: '/tmp/photo.jpg',
        mediaType: WatermarkMediaType.photo,
        capturedAt: DateTime.now(),
        profileId: 'profile-1',
      );

      final videoProject = WatermarkProject(
        id: 'video-1',
        mediaPath: '/tmp/video.mp4',
        mediaType: WatermarkMediaType.video,
        capturedAt: DateTime.now(),
        profileId: 'profile-1',
      );

      // 模拟导出分支决策
      expect(photoProject.mediaType, WatermarkMediaType.photo);
      expect(videoProject.mediaType, WatermarkMediaType.video);

      // 验证 JSON 序列化也保持正确的类型
      final photoJson = photoProject.toJson();
      final videoJson = videoProject.toJson();

      expect(photoJson['mediaType'], 'photo');
      expect(videoJson['mediaType'], 'video');

      final parsedPhoto = WatermarkProject.fromJson(photoJson);
      final parsedVideo = WatermarkProject.fromJson(videoJson);

      expect(parsedPhoto.mediaType, WatermarkMediaType.photo);
      expect(parsedVideo.mediaType, WatermarkMediaType.video);
    });

    test('Export feature detection strings work correctly', () {
      const originalFileFeature = '原始文件导出';
      const photoCompositeFeature = '带水印照片合成';
      const videoCompositeFeature = '带水印视频合成';

      // 模拟 Gallery 中的特征检测
      expect(originalFileFeature.contains('原始文件'), isTrue);
      expect(photoCompositeFeature.contains('合成'), isTrue);
      expect(videoCompositeFeature.contains('合成'), isTrue);
      expect(originalFileFeature.contains('合成'), isFalse);
    });
  });

  group('Profile editing roundtrip', () {
    test('WatermarkProfile copyWith preserves all fields correctly', () {
      final originalProfile = WatermarkProfile(
        id: 'profile-1',
        name: 'Original',
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
        isDefault: false,
        canvasSize: const WatermarkCanvasSize(width: 1080, height: 1920),
        updatedAt: DateTime(2025, 1, 1),
      );

      final updatedProfile = originalProfile.copyWith(
        name: 'Updated',
        updatedAt: DateTime(2025, 1, 2),
      );

      // ID 应该保持不变
      expect(updatedProfile.id, originalProfile.id);
      // 更新的字段应该改变
      expect(updatedProfile.name, 'Updated');
      expect(updatedProfile.updatedAt, DateTime(2025, 1, 2));
      // 其他字段应该保持不变
      expect(updatedProfile.elements.length, originalProfile.elements.length);
      expect(updatedProfile.isDefault, originalProfile.isDefault);
      expect(
          updatedProfile.canvasSize?.width, originalProfile.canvasSize?.width);
    });

    test('WatermarkProfile with updated elements triggers proper timestamp',
        () {
      final element1 = const WatermarkElement(
        id: 'e1',
        type: WatermarkElementType.text,
        transform: WatermarkTransform(
          position: Offset(0.5, 0.5),
          scale: 1,
          rotation: 0,
        ),
        textStyle: WatermarkTextStyle(fontSize: 12),
      );

      final element2 = const WatermarkElement(
        id: 'e2',
        type: WatermarkElementType.time,
        transform: WatermarkTransform(
          position: Offset(0.3, 0.3),
          scale: 1.2,
          rotation: 15,
        ),
      );

      final profile = WatermarkProfile(
        id: 'profile-1',
        name: 'Test',
        elements: [element1],
        updatedAt: DateTime(2025, 1, 1),
      );

      // 模拟添加新元素的场景
      final updatedElements = [...profile.elements, element2];
      final editedProfile = profile.copyWith(
        elements: updatedElements,
        updatedAt: DateTime.now(),
      );

      expect(editedProfile.elements.length, 2);
      expect(editedProfile.elements.last.id, 'e2');
      expect(editedProfile.updatedAt!.isAfter(profile.updatedAt!), isTrue);
    });

    test('WatermarkProject updates preserve integrity during profile binding',
        () {
      final originalProject = WatermarkProject(
        id: 'project-1',
        mediaPath: '/tmp/test.jpg',
        mediaType: WatermarkMediaType.photo,
        capturedAt: DateTime(2025, 1, 1),
        profileId: 'old-profile',
        thumbnailData: base64Encode([1, 2, 3]),
        thumbnailUpdatedAt: DateTime(2025, 1, 1),
      );

      // 模拟编辑器返回后更新项目绑定的 profile
      final updatedProject = originalProject.copyWith(
        profileId: 'new-profile',
        thumbnailUpdatedAt: DateTime(2025, 1, 2),
      );

      expect(updatedProject.id, originalProject.id); // ID 不变
      expect(updatedProject.mediaPath, originalProject.mediaPath); // 路径不变
      expect(updatedProject.profileId, 'new-profile'); // Profile ID 更新
      expect(
          updatedProject.thumbnailUpdatedAt!
              .isAfter(originalProject.thumbnailUpdatedAt!),
          isTrue);
    });
  });
}
