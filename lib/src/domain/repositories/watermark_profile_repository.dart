import 'package:fmark_camera/src/domain/models/watermark_profile.dart';

abstract class WatermarkProfileRepository {
  Future<List<WatermarkProfile>> loadProfiles();

  Future<void> saveProfiles(List<WatermarkProfile> profiles);
}
