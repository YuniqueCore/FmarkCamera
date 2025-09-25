import 'package:flutter/material.dart';

class WatermarkTextStyle {
  const WatermarkTextStyle({
    this.fontSize = 18,
    this.fontWeight = FontWeight.w600,
    this.color = Colors.white,
    this.background,
    this.shadow,
    this.letterSpacing,
  });

  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final Color? background;
  final Shadow? shadow;
  final double? letterSpacing;

  WatermarkTextStyle copyWith({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    Color? background,
    Shadow? shadow,
    double? letterSpacing,
  }) {
    return WatermarkTextStyle(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      color: color ?? this.color,
      background: background ?? this.background,
      shadow: shadow ?? this.shadow,
      letterSpacing: letterSpacing ?? this.letterSpacing,
    );
  }

  TextStyle asTextStyle() {
    final backgroundPaint = background == null ? null : Paint()
      ?..color = background!
      ..style = PaintingStyle.fill;
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      background: backgroundPaint,
      shadows: shadow == null ? null : <Shadow>[shadow!],
      letterSpacing: letterSpacing,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fontSize': fontSize,
        'fontWeight': fontWeight.index,
        'color': color.value,
        'background': background?.value,
        'shadow': shadow == null
            ? null
            : <String, dynamic>{
                'color': shadow!.color.value,
                'offset': <String, double>{
                  'dx': shadow!.offset.dx,
                  'dy': shadow!.offset.dy,
                },
                'blurRadius': shadow!.blurRadius,
              },
        'letterSpacing': letterSpacing,
      };

  factory WatermarkTextStyle.fromJson(Map<String, dynamic> json) {
    final shadowJson = json['shadow'] as Map<String, dynamic>?;
    final offsetJson = shadowJson?['offset'] as Map<String, dynamic>?;
    return WatermarkTextStyle(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18,
      fontWeight: FontWeight
          .values[(json['fontWeight'] as int?) ?? FontWeight.w600.index],
      color: Color((json['color'] as int?) ?? Colors.white.value),
      background: (json['background'] as int?) == null
          ? null
          : Color(json['background'] as int),
      shadow: shadowJson == null
          ? null
          : Shadow(
              color:
                  Color((shadowJson['color'] as int?) ?? Colors.black54.value),
              offset: Offset(
                (offsetJson?['dx'] as num?)?.toDouble() ?? 0,
                (offsetJson?['dy'] as num?)?.toDouble() ?? 0,
              ),
              blurRadius: (shadowJson['blurRadius'] as num?)?.toDouble() ?? 0,
            ),
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble(),
    );
  }
}
