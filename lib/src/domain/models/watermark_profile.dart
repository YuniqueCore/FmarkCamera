import 'package:fmark_camera/src/domain/models/watermark_element.dart';

typedef WatermarkElementList = List<WatermarkElement>;

class WatermarkProfile {
  const WatermarkProfile({
    required this.id,
    required this.name,
    required this.elements,
    this.isDefault = false,
    this.updatedAt,
  });

  final String id;
  final String name;
  final WatermarkElementList elements;
  final bool isDefault;
  final DateTime? updatedAt;

  WatermarkProfile copyWith({
    String? name,
    WatermarkElementList? elements,
    bool? isDefault,
    DateTime? updatedAt,
  }) {
    return WatermarkProfile(
      id: id,
      name: name ?? this.name,
      elements: elements ?? this.elements,
      isDefault: isDefault ?? this.isDefault,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'elements': elements.map((element) => element.toJson()).toList(),
        'isDefault': isDefault,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory WatermarkProfile.fromJson(Map<String, dynamic> json) {
    final elementsJson = json['elements'] as List<dynamic>? ?? <dynamic>[];
    return WatermarkProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed',
      elements: elementsJson
          .map((elementJson) => WatermarkElement.fromJson(
                elementJson as Map<String, dynamic>,
              ))
          .toList(),
      isDefault: json['isDefault'] as bool? ?? false,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }
}
