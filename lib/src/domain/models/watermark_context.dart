import 'location_snapshot.dart';
import 'weather_snapshot.dart';

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
