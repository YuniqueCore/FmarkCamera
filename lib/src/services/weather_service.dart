import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:fmark_camera/src/domain/models/weather_snapshot.dart';

class WeatherService {
  Future<WeatherSnapshot?> loadWeather(
      {required double latitude, required double longitude}) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,weather_code',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return null;
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) {
      return null;
    }
    final temperature = (current['temperature_2m'] as num?)?.toDouble();
    final code = current['weather_code'];
    return WeatherSnapshot(
      temperatureCelsius: temperature ?? 0,
      description: _describeCode(code),
    );
  }

  String? _describeCode(dynamic code) {
    if (code is! num) {
      return null;
    }
    const descriptions = <int, String>{
      0: '晴朗',
      1: '局部多云',
      2: '多云',
      3: '阴',
      45: '雾',
      48: '雾冻',
      51: '小毛毛雨',
      53: '中毛毛雨',
      55: '大毛毛雨',
      61: '小雨',
      63: '中雨',
      65: '大雨',
      71: '小雪',
      73: '中雪',
      75: '大雪',
      95: '雷雨',
    };
    return descriptions[code.toInt()] ?? '天气未知';
  }
}
