import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/watermark_element.dart';
import '../../domain/models/watermark_profile.dart';
import '../../domain/models/watermark_text_style.dart';
import '../../domain/models/watermark_transform.dart';
import '../../domain/repositories/watermark_profile_repository.dart';
import '../storage/local_file_storage.dart';

class WatermarkProfileFileRepository implements WatermarkProfileRepository {
  WatermarkProfileFileRepository(this.storage);

  static const String _fileName = 'watermark_profiles.json';
  final LocalFileStorage storage;
  final Uuid _uuid = const Uuid();
  List<WatermarkProfile>? _cache;

  @override
  Future<List<WatermarkProfile>> loadProfiles() async {
    if (_cache != null) {
      return _cache!;
    }
    final list = await storage.readJsonList(_fileName);
    if (list.isEmpty) {
      _cache = _buildDefaultProfiles();
      await saveProfiles(_cache!);
      return _cache!;
    }
    _cache = list.map(WatermarkProfile.fromJson).toList();
    return _cache!;
  }

  @override
  Future<void> saveProfiles(List<WatermarkProfile> profiles) async {
    _cache = profiles;
    await storage.writeJsonList(
      _fileName,
      profiles.map((profile) => profile.toJson()).toList(),
    );
  }

  List<WatermarkProfile> _buildDefaultProfiles() {
    final elements = <WatermarkElement>[
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.time,
        transform: const WatermarkTransform(
          position: Offset(0.05, 0.75),
          scale: 1.0,
          rotation: 0,
        ),
        textStyle: const WatermarkTextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          shadow: Shadow(
            blurRadius: 4,
            color: Colors.black54,
            offset: Offset(0, 1),
          ),
        ),
      ),
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.location,
        transform: const WatermarkTransform(
          position: Offset(0.05, 0.82),
          scale: 1.0,
          rotation: 0,
        ),
        textStyle: const WatermarkTextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
      WatermarkElement(
        id: _uuid.v4(),
        type: WatermarkElementType.weather,
        transform: const WatermarkTransform(
          position: Offset(0.05, 0.9),
          scale: 1.0,
          rotation: 0,
        ),
        textStyle: const WatermarkTextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    ];

    return <WatermarkProfile>[
      WatermarkProfile(
        id: _uuid.v4(),
        name: '默认模板',
        elements: elements.sorted((a, b) => a.zIndex.compareTo(b.zIndex)).toList(),
        isDefault: true,
        updatedAt: DateTime.now(),
      ),
    ];
  }
}
