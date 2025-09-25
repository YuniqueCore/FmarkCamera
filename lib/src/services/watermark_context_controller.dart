import 'dart:async';

import 'package:flutter/material.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';
import 'package:fmark_camera/src/domain/models/weather_snapshot.dart';
import 'package:fmark_camera/src/services/location_service.dart';
import 'package:fmark_camera/src/services/weather_service.dart';
import 'package:fmark_camera/src/services/bootstrapper.dart';

class WatermarkContextController extends ChangeNotifier {
  WatermarkContextController({
    required LocationService locationService,
    required WeatherService weatherService,
    this.bootstrapper,
  })  : _locationService = locationService,
        _weatherService = weatherService;

  final LocationService _locationService;
  final WeatherService _weatherService;
  final Bootstrapper? bootstrapper;

  WatermarkContext _context = WatermarkContext(now: DateTime.now());
  Timer? _timer;

  WatermarkContext get context => _context;

  Future<void> start() async {
    await refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _context = _context.copyWith(now: DateTime.now());
      notifyListeners();
    });
  }

  Future<void> refresh() async {
    final location = await _locationService.resolveCurrentLocation();
    WeatherSnapshot? weather;
    if (location != null) {
      weather = await _weatherService.loadWeather(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    }
    _context = WatermarkContext(
      now: DateTime.now(),
      location: location,
      weather: weather,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
