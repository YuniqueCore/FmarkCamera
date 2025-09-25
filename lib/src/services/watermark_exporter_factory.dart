import 'package:fmark_camera/src/services/watermark_exporter.dart';
import 'package:fmark_camera/src/services/watermark_exporter_io.dart'
    if (dart.library.html)
        'package:fmark_camera/src/services/watermark_exporter_web.dart'
    as impl;

class WatermarkExporterFactory {
  const WatermarkExporterFactory._();

  static WatermarkExporter create() => impl.createWatermarkExporter();
}

