import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:fmark_camera/src/domain/models/watermark_element.dart';
import 'package:fmark_camera/src/domain/models/watermark_profile.dart';
import 'package:fmark_camera/src/domain/repositories/watermark_profile_repository.dart';

class WatermarkProfilesController extends ChangeNotifier {
  WatermarkProfilesController({required this.repository});

  final WatermarkProfileRepository repository;

  List<WatermarkProfile> _profiles = const <WatermarkProfile>[];
  String? _activeProfileId;

  List<WatermarkProfile> get profiles => _profiles;
  WatermarkProfile? get activeProfile {
    if (_profiles.isEmpty) {
      return null;
    }
    if (_activeProfileId == null) {
      return _profiles.first;
    }
    return _profiles.firstWhere(
      (profile) => profile.id == _activeProfileId,
      orElse: () => _profiles.first,
    );
  }

  Future<void> load() async {
    final loaded = await repository.loadProfiles();
    _profiles = [...loaded];
    if (_profiles.isEmpty) {
      final uuid = const Uuid();
      final fallback = WatermarkProfile(
        id: uuid.v4(),
        name: '默认水印',
        elements: const <WatermarkElement>[],
        isDefault: true,
        canvasSize: const WatermarkCanvasSize(width: 1080, height: 1920),
        updatedAt: DateTime.now(),
      );
      _profiles = [fallback];
      _activeProfileId = fallback.id;
      await repository.saveProfiles(_profiles);
    } else {
      final defaultProfile = _profiles.firstWhere(
        (item) => item.isDefault,
        orElse: () => _profiles.first,
      );
      _activeProfileId = defaultProfile.id;
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await repository.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> setActive(String profileId) async {
    if (_activeProfileId == profileId) {
      return;
    }
    if (_profiles.every((profile) => profile.id != profileId)) {
      return;
    }
    _activeProfileId = profileId;
    notifyListeners();
  }

  Future<void> ensureCanvasSize(
    WatermarkCanvasSize canvasSize, {
    bool force = false,
    double tolerance = 0.01,
  }) async {
    bool changed = false;
    _profiles = _profiles.map((profile) {
      final current = profile.canvasSize;
      final shouldUpdate = current == null ||
          force ||
          !_isCanvasApproxEqual(current, canvasSize, tolerance: tolerance);
      if (!shouldUpdate) {
        return profile;
      }
      changed = true;
      return profile.copyWith(
        canvasSize: canvasSize,
        updatedAt: DateTime.now(),
      );
    }).toList();
    if (changed) {
      await _persist();
    } else {
      notifyListeners();
    }
  }

  bool _isCanvasApproxEqual(
    WatermarkCanvasSize a,
    WatermarkCanvasSize b, {
    double tolerance = 0.01,
  }) {
    double scale(double value) => value.abs().clamp(1, double.infinity);
    bool close(double x, double y) => (x - y).abs() <= tolerance * scale(y);
    return close(a.width, b.width) && close(a.height, b.height);
  }

  Future<WatermarkProfile> createProfile({
    required String id,
    required String name,
    required WatermarkCanvasSize canvasSize,
  }) async {
    final profile = WatermarkProfile(
      id: id,
      name: name,
      elements: const <WatermarkElement>[],
      canvasSize: canvasSize,
      isDefault: _profiles.isEmpty,
      updatedAt: DateTime.now(),
    );
    _profiles = [..._profiles, profile];
    _activeProfileId = profile.id;
    await _persist();
    return profile;
  }

  Future<void> updateProfile(WatermarkProfile profile) async {
    _profiles = _profiles
        .map((item) => item.id == profile.id ? profile : item)
        .toList();
    await _persist();
  }

  Future<void> deleteProfile(String profileId) async {
    if (_profiles.length <= 1) {
      return;
    }
    _profiles = _profiles.where((item) => item.id != profileId).toList();
    if (_activeProfileId == profileId) {
      _activeProfileId = _profiles.first.id;
    }
    await _persist();
  }

  Future<void> duplicateProfile({
    required WatermarkProfile source,
    required String newId,
    required String newName,
  }) async {
    final uuid = const Uuid();
    final duplicatedElements = source.elements
        .map(
          (element) => WatermarkElement(
            id: uuid.v4(),
            type: element.type,
            transform: element.transform,
            opacity: element.opacity,
            textStyle: element.textStyle,
            payload: element.payload,
            zIndex: element.zIndex,
            isLocked: element.isLocked,
          ),
        )
        .toList();
    final duplicated = WatermarkProfile(
      id: newId,
      name: newName,
      elements: duplicatedElements,
      isDefault: false,
      canvasSize: source.canvasSize,
      updatedAt: DateTime.now(),
    );
    _profiles = [..._profiles, duplicated];
    _activeProfileId = duplicated.id;
    await _persist();
  }

  Future<void> renameProfile(String profileId, String newName) async {
    _profiles = _profiles
        .map((item) => item.id == profileId
            ? item.copyWith(name: newName, updatedAt: DateTime.now())
            : item)
        .toList();
    await _persist();
  }

  Future<void> setDefaultProfile(String profileId) async {
    _profiles = _profiles
        .map((item) => item.copyWith(isDefault: item.id == profileId))
        .toList();
    _activeProfileId = profileId;
    await _persist();
  }
}
