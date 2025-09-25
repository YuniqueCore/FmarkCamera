import 'package:fmark_camera/src/data/repositories/project_file_repository.dart';
import 'package:fmark_camera/src/data/repositories/watermark_profile_file_repository.dart';
import 'package:fmark_camera/src/data/storage/local_file_storage.dart';
import 'package:fmark_camera/src/domain/repositories/project_repository.dart';
import 'package:fmark_camera/src/domain/repositories/watermark_profile_repository.dart';
import 'package:fmark_camera/src/services/location_service.dart';
import 'package:fmark_camera/src/services/watermark_context_controller.dart';
import 'package:fmark_camera/src/services/watermark_exporter.dart';
import 'package:fmark_camera/src/services/watermark_renderer.dart';
import 'package:fmark_camera/src/services/weather_service.dart';

class Bootstrapper {
  Bootstrapper();

  late final LocalFileStorage storage;
  late final WatermarkProfileRepository profileRepository;
  late final ProjectRepository projectRepository;
  late final LocationService locationService;
  late final WeatherService weatherService;
  late final WatermarkContextController contextController;
  late final WatermarkRenderer renderer;
  late final WatermarkExporter exporter;

  Future<void> initialize() async {
    storage = LocalFileStorage.create();
    profileRepository = WatermarkProfileFileRepository(storage);
    projectRepository = ProjectFileRepository(storage);
    locationService = LocationService();
    weatherService = WeatherService();
    contextController = WatermarkContextController(
      locationService: locationService,
      weatherService: weatherService,
    );
    renderer = WatermarkRenderer();
    exporter = WatermarkExporter();
    await profileRepository.loadProfiles();
    await contextController.start();
  }
}
