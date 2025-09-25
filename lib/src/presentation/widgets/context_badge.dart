import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:fmark_camera/src/domain/models/watermark_context.dart';

class ContextBadge extends StatelessWidget {
  const ContextBadge({super.key, required this.contextData});

  final WatermarkContext contextData;

  @override
  Widget build(BuildContext context) {
    final timeText = DateFormat('yyyy-MM-dd HH:mm').format(contextData.now);
    final locationText =
        contextData.location?.city ?? contextData.location?.address ?? '定位中';
    final weatherText = contextData.weather == null
        ? '天气获取中'
        : '${contextData.weather!.temperatureCelsius.toStringAsFixed(1)}°C ${contextData.weather!.description ?? ''}'
            .trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(timeText,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: Colors.white)),
            const SizedBox(height: 4),
            Text(locationText,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            Text(weatherText,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
