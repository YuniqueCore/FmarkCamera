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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'now': now.toIso8601String(),
        'location': location?.toJson(),
        'weather': weather?.toJson(),
      };

  factory WatermarkContext.fromJson(Map<String, dynamic> json) {
    return WatermarkContext(
      now: DateTime.tryParse(json['now'] as String? ?? '') ?? DateTime.now(),
      location: json['location'] == null
          ? null
          : LocationSnapshot.fromJson(
              json['location'] as Map<String, dynamic>,
            ),
      weather: json['weather'] == null
          ? null
          : WeatherSnapshot.fromJson(
              json['weather'] as Map<String, dynamic>,
            ),
    );
  }
}
