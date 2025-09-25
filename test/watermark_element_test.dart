import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_element_payload.dart';
import 'package:fmark_camera/src/domain/models/watermark_transform.dart';
import 'package:fmark_camera/src/domain/models/watermark_text_style.dart';

void main() {
  group('WatermarkElement creation and serialization', () {
    test('creates text element with proper defaults', () {
      const element = WatermarkElement(
        id: 'test-id',
        type: WatermarkElementType.text,
        transform: WatermarkTransform(
          position: Offset(0.5, 0.5),
          scale: 1.0,
          rotation: 0.0,
        ),
        payload: WatermarkElementPayload(text: 'Hello World'),
        textStyle: WatermarkTextStyle(
          fontSize: 16,
          color: Color(0xFFFFFFFF),
        ),
      );

      expect(element.id, 'test-id');
      expect(element.type, WatermarkElementType.text);
      expect(element.transform.position, const Offset(0.5, 0.5));
      expect(element.payload.text, 'Hello World');
      expect(element.textStyle!.fontSize, 16);
    });

    test('creates location element with proper type', () {
      final element = WatermarkElement(
        id: 'location-id',
        type: WatermarkElementType.location,
        transform: const WatermarkTransform(
          position: Offset(0.1, 0.9),
          scale: 0.8,
          rotation: 0.0,
        ),
      );

      expect(element.type, WatermarkElementType.location);
      expect(element.transform.position, const Offset(0.1, 0.9));
      expect(element.transform.scale, 0.8);
    });

    test('creates time element with proper type', () {
      final element = WatermarkElement(
        id: 'time-id',
        type: WatermarkElementType.time,
        transform: const WatermarkTransform(
          position: Offset(0.9, 0.1),
          scale: 1.2,
          rotation: 0.0,
        ),
      );

      expect(element.type, WatermarkElementType.time);
      expect(element.transform.scale, 1.2);
    });

    test('creates weather element with proper type', () {
      final element = WatermarkElement(
        id: 'weather-id',
        type: WatermarkElementType.weather,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.1),
          scale: 1.0,
          rotation: 45.0,
        ),
      );

      expect(element.type, WatermarkElementType.weather);
      expect(element.transform.rotation, 45.0);
    });

    test('creates image element with payload', () {
      final element = WatermarkElement(
        id: 'image-id',
        type: WatermarkElementType.image,
        transform: const WatermarkTransform(
          position: Offset(0.2, 0.8),
          scale: 0.5,
          rotation: 0.0,
        ),
        payload: const WatermarkElementPayload(imagePath: '/path/to/image.png'),
      );

      expect(element.type, WatermarkElementType.image);
      expect(element.payload.imagePath, '/path/to/image.png');
      expect(element.transform.scale, 0.5);
    });
  });

  group('WatermarkElement JSON serialization', () {
    test('serializes and deserializes text element correctly', () {
      final original = WatermarkElement(
        id: 'text-1',
        type: WatermarkElementType.text,
        transform: const WatermarkTransform(
          position: Offset(0.3, 0.7),
          scale: 1.5,
          rotation: 30.0,
        ),
        payload: const WatermarkElementPayload(text: 'Test Text'),
        textStyle: const WatermarkTextStyle(
          fontSize: 18,
          color: Color(0xFF123456),
          fontWeight: FontWeight.bold,
        ),
      );

      final json = original.toJson();
      final restored = WatermarkElement.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.transform.position, original.transform.position);
      expect(restored.transform.scale, original.transform.scale);
      expect(restored.transform.rotation, original.transform.rotation);
      expect(restored.payload.text, original.payload.text);
      expect(restored.textStyle!.fontSize, original.textStyle!.fontSize);
      expect(restored.textStyle!.color, original.textStyle!.color);
    });

    test('serializes and deserializes image element correctly', () {
      final original = WatermarkElement(
        id: 'image-1',
        type: WatermarkElementType.image,
        transform: const WatermarkTransform(
          position: Offset(0.8, 0.2),
          scale: 0.75,
          rotation: -15.0,
        ),
        payload: const WatermarkElementPayload(
          imagePath: '/storage/images/logo.png',
        ),
      );

      final json = original.toJson();
      final restored = WatermarkElement.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      expect(restored.payload.imagePath, original.payload.imagePath);
    });

    test('handles null payload gracefully', () {
      final original = WatermarkElement(
        id: 'time-1',
        type: WatermarkElementType.time,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.5),
          scale: 1.0,
          rotation: 0.0,
        ),
      );

      final json = original.toJson();
      final restored = WatermarkElement.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.type, original.type);
      // Payload is always created from JSON, but should have null content
      expect(restored.payload.text, isNull);
      expect(restored.payload.imagePath, isNull);
    });

    test('handles missing fields in JSON gracefully', () {
      final incompleteJson = <String, dynamic>{
        'id': 'incomplete-1',
        'type': 'text',
        // Missing transform, payload, textStyle
      };

      final element = WatermarkElement.fromJson(incompleteJson);

      expect(element.id, 'incomplete-1');
      expect(element.type, WatermarkElementType.text);
      expect(element.transform.position, const Offset(0.5, 0.5)); // default
      expect(element.transform.scale, 1.0); // default
      expect(element.transform.rotation, 0.0); // default
    });
  });

  group('WatermarkTransform operations', () {
    test('creates transform with proper values', () {
      const transform = WatermarkTransform(
        position: Offset(0.25, 0.75),
        scale: 1.25,
        rotation: 90.0,
      );

      expect(transform.position.dx, 0.25);
      expect(transform.position.dy, 0.75);
      expect(transform.scale, 1.25);
      expect(transform.rotation, 90.0);
    });

    test('copyWith updates only specified fields', () {
      const original = WatermarkTransform(
        position: Offset(0.1, 0.1),
        scale: 1.0,
        rotation: 0.0,
      );

      final updated = original.copyWith(
        position: const Offset(0.9, 0.9),
        scale: 2.0,
      );

      expect(updated.position, const Offset(0.9, 0.9));
      expect(updated.scale, 2.0);
      expect(updated.rotation, 0.0); // unchanged
    });

    test('serializes and deserializes correctly', () {
      const original = WatermarkTransform(
        position: Offset(0.456, 0.789),
        scale: 1.234,
        rotation: 123.45,
      );

      final json = original.toJson();
      final restored = WatermarkTransform.fromJson(json);

      expect(restored.position.dx, closeTo(original.position.dx, 0.001));
      expect(restored.position.dy, closeTo(original.position.dy, 0.001));
      expect(restored.scale, closeTo(original.scale, 0.001));
      expect(restored.rotation, closeTo(original.rotation, 0.001));
    });
  });

  group('WatermarkElementPayload handling', () {
    test('creates text payload correctly', () {
      const payload = WatermarkElementPayload(text: 'Sample Text');
      
      expect(payload.text, 'Sample Text');
      expect(payload.imagePath, isNull);
    });

    test('creates image payload correctly', () {
      const payload = WatermarkElementPayload(imagePath: '/path/image.jpg');
      
      expect(payload.imagePath, '/path/image.jpg');
      expect(payload.text, isNull);
    });

    test('serializes and deserializes text payload', () {
      const original = WatermarkElementPayload(text: 'Hello World');
      
      final json = original.toJson();
      final restored = WatermarkElementPayload.fromJson(json);
      
      expect(restored.text, original.text);
      expect(restored.imagePath, isNull);
    });

    test('serializes and deserializes image payload', () {
      const original = WatermarkElementPayload(imagePath: '/storage/logo.png');
      
      final json = original.toJson();
      final restored = WatermarkElementPayload.fromJson(json);
      
      expect(restored.imagePath, original.imagePath);
      expect(restored.text, isNull);
    });
  });

  group('WatermarkTextStyle configuration', () {
    test('creates text style with all properties', () {
      const style = WatermarkTextStyle(
        fontSize: 24,
        color: Color(0xFFFF5722),
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      );

      expect(style.fontSize, 24);
      expect(style.color, const Color(0xFFFF5722));
      expect(style.fontWeight, FontWeight.w600);
      expect(style.letterSpacing, 1.2);
    });

    test('copyWith updates only specified properties', () {
      const original = WatermarkTextStyle(
        fontSize: 16,
        color: Color(0xFF000000),
        fontWeight: FontWeight.normal,
      );

      final updated = original.copyWith(
        fontSize: 20,
        color: const Color(0xFFFFFFFF),
      );

      expect(updated.fontSize, 20);
      expect(updated.color, const Color(0xFFFFFFFF));
      expect(updated.fontWeight, FontWeight.normal); // unchanged
    });

    test('serializes and deserializes correctly', () {
      const original = WatermarkTextStyle(
        fontSize: 18,
        color: Color(0xFF2196F3),
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      );

      final json = original.toJson();
      final restored = WatermarkTextStyle.fromJson(json);

      expect(restored.fontSize, original.fontSize);
      expect(restored.color, original.color);
      expect(restored.fontWeight, original.fontWeight);
      expect(restored.letterSpacing, original.letterSpacing);
    });

    test('handles missing properties with defaults', () {
      final minimalJson = <String, dynamic>{
        'fontSize': 14,
        // Missing color, fontWeight, letterSpacing
      };

      final style = WatermarkTextStyle.fromJson(minimalJson);

      expect(style.fontSize, 14);
      expect(style.color, const Color(0xFFFFFFFF)); // default white
      expect(style.fontWeight, FontWeight.w600); // default from WatermarkTextStyle
      expect(style.letterSpacing, isNull); // default null
    });
  });

  group('Element editing workflow simulation', () {
    test('element transformation updates work correctly', () {
      final element = WatermarkElement(
        id: 'editable-1',
        type: WatermarkElementType.text,
        transform: const WatermarkTransform(
          position: Offset(0.5, 0.5),
          scale: 1.0,
          rotation: 0.0,
        ),
        payload: const WatermarkElementPayload(text: 'Original Text'),
      );

      // 模拟拖拽操作
      final draggedElement = element.copyWith(
        transform: element.transform.copyWith(
          position: const Offset(0.7, 0.3),
        ),
      );

      // 模拟缩放操作
      final scaledElement = draggedElement.copyWith(
        transform: draggedElement.transform.copyWith(
          scale: 1.5,
        ),
      );

      // 模拟旋转操作
      final rotatedElement = scaledElement.copyWith(
        transform: scaledElement.transform.copyWith(
          rotation: 45.0,
        ),
      );

      // 模拟文本内容更新
      final updatedElement = rotatedElement.copyWith(
        payload: const WatermarkElementPayload(text: 'Updated Text'),
      );

      expect(updatedElement.id, element.id); // ID 保持不变
      expect(updatedElement.type, element.type); // 类型保持不变
      expect(updatedElement.transform.position, const Offset(0.7, 0.3));
      expect(updatedElement.transform.scale, 1.5);
      expect(updatedElement.transform.rotation, 45.0);
      expect(updatedElement.payload.text, 'Updated Text');
    });

    test('element copying preserves all properties', () {
      final original = WatermarkElement(
        id: 'original-1',
        type: WatermarkElementType.image,
        transform: const WatermarkTransform(
          position: Offset(0.2, 0.8),
          scale: 0.8,
          rotation: 15.0,
        ),
        payload: const WatermarkElementPayload(imagePath: '/test/image.png'),
        textStyle: const WatermarkTextStyle(
          fontSize: 20,
          color: Color(0xFF9C27B0),
        ),
      );

      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.type, original.type);
      expect(copied.transform.position, original.transform.position);
      expect(copied.transform.scale, original.transform.scale);
      expect(copied.transform.rotation, original.transform.rotation);
      expect(copied.payload.imagePath, original.payload.imagePath);
      expect(copied.textStyle!.fontSize, original.textStyle!.fontSize);
      expect(copied.textStyle!.color, original.textStyle!.color);
    });

    test('multiple elements can be managed independently', () {
      final elements = [
        WatermarkElement(
          id: 'elem-1',
          type: WatermarkElementType.time,
          transform: const WatermarkTransform(
            position: Offset(0.1, 0.1),
            scale: 1.0,
            rotation: 0.0,
          ),
        ),
        WatermarkElement(
          id: 'elem-2',
          type: WatermarkElementType.location,
          transform: const WatermarkTransform(
            position: Offset(0.9, 0.9),
            scale: 0.8,
            rotation: 0.0,
          ),
        ),
        WatermarkElement(
          id: 'elem-3',
          type: WatermarkElementType.weather,
          transform: const WatermarkTransform(
            position: Offset(0.5, 0.1),
            scale: 1.2,
            rotation: 30.0,
          ),
        ),
      ];

      // 模拟更新第二个元素
      final updatedElements = elements.map((elem) {
        if (elem.id == 'elem-2') {
          return elem.copyWith(
            transform: elem.transform.copyWith(
              position: const Offset(0.8, 0.8),
              scale: 1.0,
            ),
          );
        }
        return elem;
      }).toList();

      expect(updatedElements.length, 3);
      expect(updatedElements[0].transform.position, const Offset(0.1, 0.1)); // 未变
      expect(updatedElements[1].transform.position, const Offset(0.8, 0.8)); // 已更新
      expect(updatedElements[1].transform.scale, 1.0); // 已更新
      expect(updatedElements[2].transform.rotation, 30.0); // 未变
    });
  });
}
