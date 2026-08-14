import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Icon used for the "Smart Matches" entry point.
///
/// Two overlapping circles (people/tasks being paired) with a small spark
/// badge for the "smart"/AI cue — reads as "matching", not a plain star.
class SmartMatchIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const SmartMatchIcon({super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? Theme.of(context).iconTheme.color ?? Colors.black87;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.join_full, size: size, color: iconColor),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              width: size * 0.42,
              height: size * 0.42,
              decoration: BoxDecoration(
                color: AppTheme.arahPurple,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.bolt,
                size: size * 0.28,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
