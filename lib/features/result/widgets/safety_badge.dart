import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/category_style.dart';
import '../../../models/ingredient.dart';

class SafetyBadge extends StatelessWidget {
  final SafetyLevel level;
  final bool compact;
  final bool showIcon;

  const SafetyBadge({
    super.key,
    required this.level,
    this.compact = false,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(level);

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: config.bgColor,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(config.icon, size: compact ? 12 : 14, color: config.color),
            SizedBox(width: compact ? 4 : 5),
          ],
          Text(
            config.label,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  _SafetyConfig _getConfig(SafetyLevel level) {
    return _SafetyConfig(
      label: _shortLabel(level),
      color: level.color,
      bgColor: level.lightColor,
      icon: level.icon,
    );
  }

  static String _shortLabel(SafetyLevel level) {
    switch (level) {
      case SafetyLevel.safe:
        return AppStrings.safeLabel;
      case SafetyLevel.caution:
        return AppStrings.cautionLabel;
      case SafetyLevel.warning:
        return AppStrings.warningLabel;
      case SafetyLevel.danger:
        return AppStrings.dangerLabel;
      case SafetyLevel.unknown:
        return AppStrings.unknownLabel;
    }
  }
}

class _SafetyConfig {
  final String label;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _SafetyConfig({
    required this.label,
    required this.color,
    required this.bgColor,
    required this.icon,
  });
}

class OverallSafetyIndicator extends StatelessWidget {
  final SafetyLevel level;

  const OverallSafetyIndicator({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(level);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            config.color.withOpacity(0.12),
            config.color.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: config.color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(config.icon, color: config.color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.overallSafety,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  config.label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: config.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _SafetyConfig _getConfig(SafetyLevel level) {
    return _SafetyConfig(
      label: _longLabel(level),
      color: level.color,
      bgColor: level.lightColor,
      icon: level.icon,
    );
  }

  static String _longLabel(SafetyLevel level) {
    switch (level) {
      case SafetyLevel.safe:
        return 'Produk Aman';
      case SafetyLevel.caution:
        return 'Perlu Perhatian';
      case SafetyLevel.warning:
        return 'Ada Peringatan';
      case SafetyLevel.danger:
        return 'Berbahaya';
      case SafetyLevel.unknown:
        return 'Tidak Diketahui';
    }
  }
}
