import 'package:fmark_camera/src/domain/models/location_snapshot.dart';
import 'package:fmark_camera/src/domain/models/weather_snapshot.dart';

class WatermarkContext {
  const WatermarkContext({
    required this.now,
    this.location,
    this.weather,
  });

  final DateTime now;
  final LocationSnapshot? location;
  final WeatherSnapshot? weather;

  WatermarkContext copyWith({
    DateTime? now,
    LocationSnapshot? location,
    WeatherSnapshot? weather,
  }) {
    return WatermarkContext(
      now: now ?? this.now,
      location: location ?? this.location,
      weather: weather ?? this.weather,
    );
  }
}
