import '../data/repositories/project_file_repository.dart';
import '../data/repositories/watermark_profile_file_repository.dart';
import '../data/storage/local_file_storage.dart';
import '../domain/repositories/project_repository.dart';
import '../domain/repositories/watermark_profile_repository.dart';
import 'location_service.dart';
import 'watermark_context_controller.dart';
import 'watermark_exporter.dart';
import 'watermark_renderer.dart';
import 'weather_service.dart';

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
    storage = const LocalFileStorage();
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
