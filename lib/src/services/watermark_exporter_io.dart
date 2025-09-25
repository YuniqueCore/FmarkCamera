import 'dart:io' show File;

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/services/watermark_exporter.dart';

class IoWatermarkExporter implements WatermarkExporter {
  const IoWatermarkExporter();

  @override
  Future<String?> composePhoto({
    required String photoPath,
    required String overlayPath,
  }) async {
    final directory = await getTemporaryDirectory();
    final outputPath = '${directory.path}/${const Uuid().v4()}.jpg';
    final command =
        "-y -i '$photoPath' -i '$overlayPath' -filter_complex overlay=0:0 -q:v 2 '$outputPath'";
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }
    return null;
  }

  @override
  Future<String?> composeVideo({
    required String videoPath,
    required String overlayPath,
  }) async {
    final directory = await getTemporaryDirectory();
    final outputPath = '${directory.path}/${const Uuid().v4()}.mp4';
    final command =
        "-y -i '$videoPath' -i '$overlayPath' -filter_complex overlay=0:0 -codec:a copy '$outputPath'";
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      return outputPath;
    }
    return null;
  }

  @override
  Future<String?> saveOverlayBytes(List<int> bytes) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/${const Uuid().v4()}.png';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  @override
  Future<String?> exportOriginal(String sourcePath) async {
    final directory = await getTemporaryDirectory();
    final originalName = p.basename(sourcePath);
    final extension = p.extension(originalName);
    final destination =
        p.join(directory.path, '${const Uuid().v4()}$extension');
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return null;
    }
    await sourceFile.copy(destination);
    return destination;
  }

  @override
  Future<String?> exportWatermarkPng(
    List<int> bytes, {
    String? suggestedName,
  }) async {
    final directory = await getTemporaryDirectory();
    final sanitizedName = (suggestedName?.trim().isNotEmpty ?? false)
        ? suggestedName!.trim()
        : 'watermark_${const Uuid().v4()}.png';
    final path = p.join(directory.path, sanitizedName);
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

WatermarkExporter createWatermarkExporter() => const IoWatermarkExporter();
