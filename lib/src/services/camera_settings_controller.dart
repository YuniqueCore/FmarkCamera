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
  static const _photoSelectionKey = 'camera.photo.selection';
  static const _videoSelectionKey = 'camera.video.selection';

  final SharedPreferences _preferences;

  ResolutionPreset _photoPreset = ResolutionPreset.high;
  ResolutionPreset _videoPreset = ResolutionPreset.high;
  CameraResolutionSelection? _photoSelection;
  CameraResolutionSelection? _videoSelection;

  final Map<String, CameraResolutionInfo> _previewInfo =
      <String, CameraResolutionInfo>{};

  ResolutionPreset get photoPreset =>
      _photoSelection?.preset ?? _photoPreset;
  ResolutionPreset get videoPreset =>
      _videoSelection?.preset ?? _videoPreset;

  ResolutionPreset presetForMode(CameraCaptureMode mode) {
    final selection = selectionForMode(mode);
    if (selection != null) {
      return selection.preset;
    }
    return mode == CameraCaptureMode.video ? _videoPreset : _photoPreset;
  }

  CameraResolutionSelection? selectionForMode(CameraCaptureMode mode) {
    return mode == CameraCaptureMode.video ? _videoSelection : _photoSelection;
  }

  CameraResolutionInfo? resolutionForMode(CameraCaptureMode mode) {
    return selectionForMode(mode)?.resolution;
  }

  CameraResolutionInfo? previewInfo(
    CameraCaptureMode mode,
    ResolutionPreset preset,
  ) {
    final selection = selectionForMode(mode);
    if (selection != null && selection.preset == preset) {
      return selection.resolution;
    }
    return _previewInfo[_previewKey(mode, preset)];
  }

  Future<void> load() async {
    _photoPreset = _readPreset(_photoPresetKey) ?? ResolutionPreset.high;
    _videoPreset = _readPreset(_videoPresetKey) ?? ResolutionPreset.high;
    _photoSelection = _readSelection(_photoSelectionKey);
    _videoSelection = _readSelection(_videoSelectionKey);

    if (_photoSelection != null) {
      _photoPreset = _photoSelection!.preset;
    }
    if (_videoSelection != null) {
      _videoPreset = _videoSelection!.preset;
    }

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
    final selectionCleared = _photoSelection != null;
    if (_photoPreset == preset && !selectionCleared) {
      return;
    }
    _photoPreset = preset;
    if (selectionCleared) {
      _photoSelection = null;
      await _preferences.remove(_photoSelectionKey);
    }
    await _preferences.setString(_photoPresetKey, preset.name);
    notifyListeners();
  }

  Future<void> setVideoPreset(ResolutionPreset preset) async {
    final selectionCleared = _videoSelection != null;
    if (_videoPreset == preset && !selectionCleared) {
      return;
    }
    _videoPreset = preset;
    if (selectionCleared) {
      _videoSelection = null;
      await _preferences.remove(_videoSelectionKey);
    }
    await _preferences.setString(_videoPresetKey, preset.name);
    notifyListeners();
  }

  Future<void> setResolutionSelection({
    required CameraCaptureMode mode,
    required CameraResolutionSelection selection,
  }) async {
    final normalized = selection.copyWith(
      resolution: selection.resolution.toPortrait(),
    );
    final current = selectionForMode(mode);
    if (current != null &&
        current.preset == normalized.preset &&
        current.cameraId == normalized.cameraId &&
        current.lensFacing == normalized.lensFacing &&
        current.resolution.approximatelyEquals(normalized.resolution)) {
      return;
    }

    if (mode == CameraCaptureMode.photo) {
      _photoSelection = normalized;
      _photoPreset = normalized.preset;
      await _preferences.setString(_photoPresetKey, normalized.preset.name);
      await _preferences.setString(
        _photoSelectionKey,
        jsonEncode(normalized.toJson()),
      );
    } else {
      _videoSelection = normalized;
      _videoPreset = normalized.preset;
      await _preferences.setString(_videoPresetKey, normalized.preset.name);
      await _preferences.setString(
        _videoSelectionKey,
        jsonEncode(normalized.toJson()),
      );
    }
    notifyListeners();
  }

  Future<void> syncResolvedSelection({
    required CameraCaptureMode mode,
    required String cameraId,
    String? lensFacing,
    required CameraResolutionInfo resolution,
  }) async {
    if (cameraId.isEmpty) {
      return;
    }
    final normalized = resolution.toPortrait();
    final current = selectionForMode(mode);
    if (current != null &&
        current.cameraId == cameraId &&
        current.lensFacing == lensFacing &&
        current.resolution.approximatelyEquals(normalized)) {
      return;
    }
    final preset = current?.preset ??
        (mode == CameraCaptureMode.video ? _videoPreset : _photoPreset);
    final updated = CameraResolutionSelection(
      resolution: normalized,
      preset: preset,
      cameraId: cameraId,
      lensFacing: lensFacing,
    );
    await setResolutionSelection(mode: mode, selection: updated);
  }

  Future<void> savePreviewInfo({
    required CameraCaptureMode mode,
    required ResolutionPreset preset,
    required CameraResolutionInfo info,
    String? cameraId,
    CameraResolutionInfo? capture,
    String? lensFacing,
  }) async {
    final key = _previewKey(mode, preset);
    final normalizedInfo = info.toPortrait();
    _previewInfo[key] = normalizedInfo;
    await _preferences.setString(key, jsonEncode(normalizedInfo.toJson()));

    final resolved = (capture ?? info).toPortrait();
    if (cameraId != null && cameraId.isNotEmpty && resolved.isValid) {
      await syncResolvedSelection(
        mode: mode,
        cameraId: cameraId,
        lensFacing: lensFacing,
        resolution: resolved,
      );
    }
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

  CameraResolutionSelection? _readSelection(String key) {
    final jsonString = _preferences.getString(key);
    if (jsonString == null) {
      return null;
    }
    try {
      final map = jsonDecode(jsonString) as Map<String, dynamic>;
      return CameraResolutionSelection.fromJson(map);
    } catch (_) {
      _preferences.remove(key);
      return null;
    }
  }

  String _previewKey(CameraCaptureMode mode, ResolutionPreset preset) {
    return '$_previewPrefix.${mode.name}.${preset.name}';
  }
}
