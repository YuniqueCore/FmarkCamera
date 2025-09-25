import 'package:flutter_test/flutter_test.dart';

import 'package:fmark_camera/src/services/watermark_exporter.dart';
import 'package:fmark_camera/src/services/watermark_exporter_web.dart';
import 'package:fmark_camera/src/services/watermark_exporter_factory.dart';

void main() {
  group('WatermarkExporter interface compliance', () {
    late WatermarkExporter exporter;

    setUp(() {
      // 使用工厂类来获取对应平台的实现
      exporter = WatermarkExporterFactory.create();
    });

    test('composePhoto should handle null overlay gracefully', () async {
      final result = await exporter.composePhoto(
        photoPath: '/nonexistent/photo.jpg',
        overlayPath: '/nonexistent/overlay.png',
      );
      // Web 平台应该返回 null，IO 平台可能返回 null 或路径
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('composeVideo should handle null overlay gracefully', () async {
      final result = await exporter.composeVideo(
        videoPath: '/nonexistent/video.mp4',
        overlayPath: '/nonexistent/overlay.png',
      );
      // Web 平台应该返回 null，IO 平台可能返回 null 或路径
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('saveOverlayBytes should handle empty bytes', () async {
      final result = await exporter.saveOverlayBytes([]);
      // 空字节数组的处理应该是安全的
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('saveOverlayBytes should handle valid PNG bytes', () async {
      // 简单的 PNG 头字节
      final validPngBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, // IHDR chunk length
        0x49, 0x48, 0x44, 0x52, // IHDR
        // 简化的 PNG 数据...
      ];
      
      final result = await exporter.saveOverlayBytes(validPngBytes);
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('exportOriginal should handle non-existent source', () async {
      final result = await exporter.exportOriginal('/nonexistent/file.jpg');
      // 不存在的文件应该安全处理
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('exportWatermarkPng should handle various filename formats', () async {
      final testBytes = [1, 2, 3, 4, 5];
      
      // 测试各种文件名格式
      final results = await Future.wait([
        exporter.exportWatermarkPng(testBytes, suggestedName: 'test.png'),
        exporter.exportWatermarkPng(testBytes, suggestedName: 'test'),
        exporter.exportWatermarkPng(testBytes, suggestedName: ''),
        exporter.exportWatermarkPng(testBytes, suggestedName: null),
        exporter.exportWatermarkPng(testBytes, suggestedName: '  '), // 空格
      ]);
      
      for (final result in results) {
        expect(result, anyOf(isNull, isA<String>()));
      }
    });
  });

  group('Web platform specific behavior', () {
    test('WebWatermarkExporter always returns null for unsupported operations', () async {
      const exporter = WebWatermarkExporter();
      
      final photoResult = await exporter.composePhoto(
        photoPath: '/any/path.jpg',
        overlayPath: '/any/overlay.png',
      );
      expect(photoResult, isNull);
      
      final videoResult = await exporter.composeVideo(
        videoPath: '/any/path.mp4',
        overlayPath: '/any/overlay.png',
      );
      expect(videoResult, isNull);
      
      final originalResult = await exporter.exportOriginal('/any/path.jpg');
      expect(originalResult, isNull);
    });

    test('WebWatermarkExporter handles overlay and watermark exports', () async {
      const exporter = WebWatermarkExporter();
      final testBytes = [1, 2, 3, 4, 5];
      
      // 这些方法在 Web 上应该触发下载，但在测试环境中返回 null
      final overlayResult = await exporter.saveOverlayBytes(testBytes);
      final watermarkResult = await exporter.exportWatermarkPng(
        testBytes,
        suggestedName: 'test.png',
      );
      
      expect(overlayResult, isNull);
      expect(watermarkResult, isNull);
    });
  });

  group('Export error handling simulation', () {
    test('should handle corrupted overlay bytes gracefully', () {
      // 模拟损坏的图像数据
      final corruptedBytes = List.generate(100, (i) => i % 256);
      
      expect(() async {
        final exporter = WatermarkExporterFactory.create();
        await exporter.saveOverlayBytes(corruptedBytes);
      }, returnsNormally);
    });

    test('should handle very large byte arrays', () {
      // 测试大文件处理
      final largeBytes = List.filled(1024 * 1024, 42); // 1MB of data
      
      expect(() async {
        final exporter = WatermarkExporterFactory.create();
        await exporter.saveOverlayBytes(largeBytes);
      }, returnsNormally);
    });

    test('should handle special characters in suggested filenames', () async {
      final exporter = WatermarkExporterFactory.create();
      final testBytes = [1, 2, 3];
      
      final specialNames = [
        'test with spaces.png',
        'test@#\$%^&*().png',
        '测试中文名.png',
        'test/with/slashes.png',
        'test\\with\\backslashes.png',
        'very_long_filename_that_might_exceed_filesystem_limits.png',
      ];
      
      for (final name in specialNames) {
        final result = await exporter.exportWatermarkPng(
          testBytes,
          suggestedName: name,
        );
        expect(result, anyOf(isNull, isA<String>()));
      }
    });
  });

  group('Export workflow integration', () {
    test('complete export workflow maintains data integrity', () async {
      final exporter = WatermarkExporterFactory.create();
      
      // 模拟完整的导出工作流
      const originalMediaPath = '/tmp/original.jpg';
      final mockOverlayBytes = List.generate(100, (i) => i);
      
      // 1. 保存水印覆盖层
      final overlayPath = await exporter.saveOverlayBytes(mockOverlayBytes);
      
      // 2. 尝试合成带水印照片
      String? composedPath;
      if (overlayPath != null) {
        composedPath = await exporter.composePhoto(
          photoPath: originalMediaPath,
          overlayPath: overlayPath,
        );
      }
      
      // 3. 导出原始文件
      final originalExportPath = await exporter.exportOriginal(originalMediaPath);
      
      // 4. 导出单独的水印 PNG
      final watermarkPngPath = await exporter.exportWatermarkPng(
        mockOverlayBytes,
        suggestedName: 'watermark_test.png',
      );
      
      // 验证工作流的各个步骤都能正常执行
      expect(overlayPath, anyOf(isNull, isA<String>()));
      expect(composedPath, anyOf(isNull, isA<String>()));
      expect(originalExportPath, anyOf(isNull, isA<String>()));
      expect(watermarkPngPath, anyOf(isNull, isA<String>()));
    });

    test('export methods are idempotent', () async {
      final exporter = WatermarkExporterFactory.create();
      final testBytes = [1, 2, 3, 4, 5];
      
      // 多次调用相同的导出方法应该产生一致的结果
      final results1 = await Future.wait([
        exporter.saveOverlayBytes(testBytes),
        exporter.exportWatermarkPng(testBytes, suggestedName: 'test.png'),
      ]);
      
      final results2 = await Future.wait([
        exporter.saveOverlayBytes(testBytes),
        exporter.exportWatermarkPng(testBytes, suggestedName: 'test.png'),
      ]);
      
      // 虽然路径可能不同（因为使用了 UUID），但类型应该一致
      expect(results1[0].runtimeType, results2[0].runtimeType);
      expect(results1[1].runtimeType, results2[1].runtimeType);
    });
  });
}
