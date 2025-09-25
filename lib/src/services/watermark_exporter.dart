import 'dart:typed_data';

import 'package:fmark_camera/src/domain/models/watermark_media_type.dart';

enum WatermarkExportDestination {
  temporary,
  gallery,
  filePicker,
  browserDownload,
}

class WatermarkExportOptions {
  const WatermarkExportOptions({
    this.destination = WatermarkExportDestination.temporary,
    this.suggestedFileName,
  });

  final WatermarkExportDestination destination;
  final String? suggestedFileName;

  WatermarkExportOptions copyWith({
    WatermarkExportDestination? destination,
    String? suggestedFileName,
  }) {
    return WatermarkExportOptions(
      destination: destination ?? this.destination,
      suggestedFileName: suggestedFileName ?? this.suggestedFileName,
    );
  }
}

class WatermarkExportResult {
  const WatermarkExportResult({
    required this.destination,
    this.outputPath,
    this.success = true,
    this.userMessage,
  });

  final WatermarkExportDestination destination;
  final String? outputPath;
  final bool success;
  final String? userMessage;

  bool get savedToGallery =>
      destination == WatermarkExportDestination.gallery && success;
}

class WatermarkMediaInput {
  const WatermarkMediaInput._({this.path, this.bytes});

  factory WatermarkMediaInput.fromPath(String path) =>
      WatermarkMediaInput._(path: path);

  factory WatermarkMediaInput.fromBytes(Uint8List bytes) =>
      WatermarkMediaInput._(bytes: bytes);

  final String? path;
  final Uint8List? bytes;

  bool get hasPath => path != null && path!.isNotEmpty;
  bool get hasBytes => bytes != null && bytes!.isNotEmpty;
}

abstract class WatermarkExporter {
  const WatermarkExporter();

  Future<WatermarkExportResult> composePhoto({
    required WatermarkMediaInput photo,
    required WatermarkMediaInput overlay,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  });

  Future<WatermarkExportResult> composeVideo({
    required WatermarkMediaInput video,
    required WatermarkMediaInput overlay,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  });

  Future<String?> saveOverlayBytes(List<int> bytes);

  Future<WatermarkExportResult> exportOriginal(
    WatermarkMediaInput source, {
    required WatermarkMediaType mediaType,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  });

  Future<WatermarkExportResult> exportWatermarkPng(
    WatermarkMediaInput overlay, {
    String? suggestedName,
    WatermarkExportOptions options = const WatermarkExportOptions(),
  });
}
