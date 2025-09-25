abstract class WatermarkExporter {
  const WatermarkExporter();

  Future<String?> composePhoto({
    required String photoPath,
    required String overlayPath,
  });

  Future<String?> composeVideo({
    required String videoPath,
    required String overlayPath,
  });

  Future<String?> saveOverlayBytes(List<int> bytes);

  Future<String?> exportOriginal(String sourcePath);

  Future<String?> exportWatermarkPng(
    List<int> bytes, {
    String? suggestedName,
  });
}
