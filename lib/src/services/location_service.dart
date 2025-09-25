import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../domain/models/location_snapshot.dart';

class LocationService {
  Future<LocationSnapshot?> resolveCurrentLocation() async {
    final permission = await _ensurePermission();
    if (!permission) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition();
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    final first = placemarks.isNotEmpty ? placemarks.first : null;
    return LocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      address: _formatAddress(first),
      city: first?.locality ?? first?.subAdministrativeArea,
    );
  }

  Future<bool> _ensurePermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return false;
    }
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }
    return true;
  }

  String? _formatAddress(Placemark? placemark) {
    if (placemark == null) {
      return null;
    }
    final segments = <String?>[
      placemark.country,
      placemark.administrativeArea,
      placemark.locality,
      placemark.subLocality,
      placemark.street,
    ];
    final filtered = segments
        .where((segment) => segment != null && segment.isNotEmpty)
        .cast<String>();
    if (filtered.isEmpty) {
      return null;
    }
    return filtered.join(' ');
  }
}
