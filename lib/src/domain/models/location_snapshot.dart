class LocationSnapshot {
  const LocationSnapshot({
    required this.latitude,
    required this.longitude,
    this.address,
    this.city,
  });

  final double latitude;
  final double longitude;
  final String? address;
  final String? city;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'city': city,
      };

  factory LocationSnapshot.fromJson(Map<String, dynamic> json) {
    return LocationSnapshot(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      address: json['address'] as String?,
      city: json['city'] as String?,
    );
  }

  LocationSnapshot copyWith({
    double? latitude,
    double? longitude,
    String? address,
    String? city,
  }) {
    return LocationSnapshot(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
    );
  }
}
