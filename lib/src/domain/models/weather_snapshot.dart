class WeatherSnapshot {
  const WeatherSnapshot({
    required this.temperatureCelsius,
    this.description,
    this.iconUrl,
  });

  final double temperatureCelsius;
  final String? description;
  final String? iconUrl;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'temperatureCelsius': temperatureCelsius,
        'description': description,
        'iconUrl': iconUrl,
      };

  factory WeatherSnapshot.fromJson(Map<String, dynamic> json) {
    return WeatherSnapshot(
      temperatureCelsius: (json['temperatureCelsius'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
    );
  }
}
