import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fmark_camera/src/domain/models/camera_resolution_info.dart';

class CameraSettingsController extends ChangeNotifier {
  CameraSettingsController({required SharedPreferences preferences})
      : _preferences = preferences;

  static const _photoPresetKey = 'camera.photo.preset';
  static const _videoPresetKey = 'camera.video.preset';
  static const _previewPrefix = 'camera.preview';

  final SharedPreferences _preferences;

  ResolutionPreset _photoPreset = ResolutionPreset.high;
  ResolutionPreset _videoPreset = ResolutionPreset.high;

  final Map<String, CameraResolutionInfo> _previewInfo =
      <String, CameraResolutionInfo>{};

  ResolutionPreset get photoPreset => _photoPreset;
  ResolutionPreset get videoPreset => _videoPreset;

  ResolutionPreset presetForMode(CameraCaptureMode mode) {
    return mode == CameraCaptureMode.video ? _videoPreset : _photoPreset;
  }

  CameraResolutionInfo? previewInfo(
    CameraCaptureMode mode,
    ResolutionPreset preset,
  ) {
    return _previewInfo[_previewKey(mode, preset)];
  }

  Future<void> load() async {
    _photoPreset = _readPreset(_photoPresetKey) ?? ResolutionPreset.high;
    _videoPreset = _readPreset(_videoPresetKey) ?? ResolutionPreset.high;

    for (final mode in CameraCaptureMode.values) {
      for (final preset in ResolutionPreset.values) {
        final key = _previewKey(mode, preset);
        final jsonString = _preferences.getString(key);
        if (jsonString == null) {
          continue;
        }
        try {
          final map = jsonDecode(jsonString) as Map<String, dynamic>;
          _previewInfo[key] = CameraResolutionInfo.fromJson(map);
        } catch (_) {
          _preferences.remove(key);
        }
      }
    }
    notifyListeners();
  }

  Future<void> setPhotoPreset(ResolutionPreset preset) async {
    if (_photoPreset == preset) {
      return;
    }
    _photoPreset = preset;
    await _preferences.setString(_photoPresetKey, preset.name);
    notifyListeners();
  }

  Future<void> setVideoPreset(ResolutionPreset preset) async {
    if (_videoPreset == preset) {
      return;
    }
    _videoPreset = preset;
    await _preferences.setString(_videoPresetKey, preset.name);
    notifyListeners();
  }

  Future<void> savePreviewInfo(
    CameraCaptureMode mode,
    ResolutionPreset preset,
    CameraResolutionInfo info,
  ) async {
    final key = _previewKey(mode, preset);
    _previewInfo[key] = info;
    await _preferences.setString(key, jsonEncode(info.toJson()));
    notifyListeners();
  }

  ResolutionPreset? _readPreset(String key) {
    final value = _preferences.getString(key);
    if (value == null) {
      return null;
    }
    return ResolutionPreset.values.firstWhere(
      (preset) => preset.name == value,
      orElse: () => ResolutionPreset.high,
    );
  }

  String _previewKey(CameraCaptureMode mode, ResolutionPreset preset) {
    return '$_previewPrefix.${mode.name}.${preset.name}';
  }
}
