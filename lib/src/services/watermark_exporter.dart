import 'dart:io';

import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class WatermarkExporter {
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

  Future<File> saveOverlayBytes(List<int> bytes) async {
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/${const Uuid().v4()}.png';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
