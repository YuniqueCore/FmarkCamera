import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'package:fmark_camera/src/domain/models/camera_resolution_info.dart';

class CameraDeviceCapabilities {
  CameraDeviceCapabilities({
    required this.cameraId,
    required this.lensFacing,
    required this.photoSizes,
    required this.videoSizes,
  });

  final String cameraId;
  final String lensFacing;
  final List<CameraResolutionInfo> photoSizes;
  final List<CameraResolutionInfo> videoSizes;
}

class CameraCapabilitiesService {
  CameraCapabilitiesService();

  static const MethodChannel _channel =
      MethodChannel('com.example.fmark_camera/capabilities');

  static const String _methodGetCapabilities = 'getCameraCapabilities';

  List<CameraDeviceCapabilities>? _cached;

  Future<List<CameraDeviceCapabilities>> loadCapabilities() async {
    if (kIsWeb) {
      // Web 端返回默认的相机能力
      return [
        CameraDeviceCapabilities(
          cameraId: '0',
          lensFacing: 'back',
          photoSizes: [
            const CameraResolutionInfo(width: 1920, height: 1080),
            const CameraResolutionInfo(width: 1280, height: 720),
            const CameraResolutionInfo(width: 640, height: 480),
          ],
          videoSizes: [
            const CameraResolutionInfo(width: 1920, height: 1080),
            const CameraResolutionInfo(width: 1280, height: 720),
            const CameraResolutionInfo(width: 640, height: 480),
          ],
        ),
        CameraDeviceCapabilities(
          cameraId: '1',
          lensFacing: 'front',
          photoSizes: [
            const CameraResolutionInfo(width: 1920, height: 1080),
            const CameraResolutionInfo(width: 1280, height: 720),
            const CameraResolutionInfo(width: 640, height: 480),
          ],
          videoSizes: [
            const CameraResolutionInfo(width: 1920, height: 1080),
            const CameraResolutionInfo(width: 1280, height: 720),
            const CameraResolutionInfo(width: 640, height: 480),
          ],
        ),
      ];
    }
    if (!Platform.isAndroid) {
      return const <CameraDeviceCapabilities>[];
    }
    if (_cached != null) {
      return _cached!;
    }
    final raw =
        await _channel.invokeListMethod<dynamic>(_methodGetCapabilities);
    final devices = raw == null
        ? <CameraDeviceCapabilities>[]
        : raw
            .whereType<Map<dynamic, dynamic>>()
            .map(_parseDevice)
            .whereType<CameraDeviceCapabilities>()
            .toList(growable: false);
    _cached = devices;
    return devices;
  }

  Future<CameraDeviceCapabilities?> findById(String cameraId) async {
    final devices = await loadCapabilities();
    for (final device in devices) {
      if (device.cameraId == cameraId) {
        return device;
      }
    }
    return null;
  }

  void invalidateCache() {
    _cached = null;
  }

  CameraDeviceCapabilities? _parseDevice(Map<dynamic, dynamic> raw) {
    final cameraId = raw['id']?.toString();
    if (cameraId == null || cameraId.isEmpty) {
      return null;
    }
    final lensFacing = raw['lensFacing']?.toString() ?? 'unknown';
    final photoSizes = _parseSizes(raw['photoSizes']);
    final videoSizes = _parseSizes(raw['videoSizes']);
    return CameraDeviceCapabilities(
      cameraId: cameraId,
      lensFacing: lensFacing,
      photoSizes: photoSizes,
      videoSizes: videoSizes,
    );
  }

  List<CameraResolutionInfo> _parseSizes(dynamic value) {
    if (value is! List) {
      return const <CameraResolutionInfo>[];
    }
    final seen = <String>{};
    final result = <CameraResolutionInfo>[];
    for (final entry in value) {
      if (entry is! Map) {
        continue;
      }
      final width = (entry['width'] as num?)?.toDouble();
      final height = (entry['height'] as num?)?.toDouble();
      if (width == null || height == null || width <= 0 || height <= 0) {
        continue;
      }

      // 确保分辨率数据合理
      final normalizedWidth = math.max(width, height);
      final normalizedHeight = math.min(width, height);

      final key = '${normalizedWidth.toStringAsFixed(0)}x${normalizedHeight.toStringAsFixed(0)}';
      if (seen.add(key)) {
        result.add(CameraResolutionInfo(width: normalizedWidth, height: normalizedHeight));
      }
    }

    // 改进排序逻辑：优先考虑常见的手机拍照分辨率
    result.sort((a, b) {
      // 首先按像素数排序（从大到小）
      final pixelCompare = (b.width * b.height).compareTo(a.width * a.height);
      if (pixelCompare != 0) {
        return pixelCompare;
      }

      // 相同像素数时，优先考虑常见的纵横比
      final aRatio = a.width / a.height;
      final bRatio = b.width / b.height;

      // 优先考虑接近4:3或16:9的比例
      const preferredRatios = [4/3, 16/9, 3/2];
      double aScore = preferredRatios.fold(1.0, (score, ratio) => math.min(score, (aRatio - ratio).abs()));
      double bScore = preferredRatios.fold(1.0, (score, ratio) => math.min(score, (bRatio - ratio).abs()));

      return aScore.compareTo(bScore);
    });

    return result;
  }
}
