import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
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
    switch (level) {
      case SafetyLevel.safe:
        return const _SafetyConfig(
          label: AppStrings.safeLabel,
          color: AppColors.safeGreen,
          bgColor: AppColors.safeGreenLight,
          icon: Icons.check_circle_rounded,
        );
      case SafetyLevel.caution:
        return const _SafetyConfig(
          label: AppStrings.cautionLabel,
          color: AppColors.cautionYellow,
          bgColor: AppColors.cautionYellowLight,
          icon: Icons.info_rounded,
        );
      case SafetyLevel.warning:
        return const _SafetyConfig(
          label: AppStrings.warningLabel,
          color: AppColors.warningOrange,
          bgColor: AppColors.warningOrangeLight,
          icon: Icons.warning_rounded,
        );
      case SafetyLevel.danger:
        return const _SafetyConfig(
          label: AppStrings.dangerLabel,
          color: AppColors.dangerRed,
          bgColor: AppColors.dangerRedLight,
          icon: Icons.dangerous_rounded,
        );
      case SafetyLevel.unknown:
        return const _SafetyConfig(
          label: AppStrings.unknownLabel,
          color: AppColors.unknownGrey,
          bgColor: AppColors.unknownGreyLight,
          icon: Icons.help_rounded,
        );
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
    switch (level) {
      case SafetyLevel.safe:
        return const _SafetyConfig(
          label: 'Produk Aman',
          color: AppColors.safeGreen,
          bgColor: AppColors.safeGreenLight,
          icon: Icons.verified_rounded,
        );
      case SafetyLevel.caution:
        return const _SafetyConfig(
          label: 'Perlu Perhatian',
          color: AppColors.cautionYellow,
          bgColor: AppColors.cautionYellowLight,
          icon: Icons.info_rounded,
        );
      case SafetyLevel.warning:
        return const _SafetyConfig(
          label: 'Ada Peringatan',
          color: AppColors.warningOrange,
          bgColor: AppColors.warningOrangeLight,
          icon: Icons.warning_rounded,
        );
      case SafetyLevel.danger:
        return const _SafetyConfig(
          label: 'Berbahaya',
          color: AppColors.dangerRed,
          bgColor: AppColors.dangerRedLight,
          icon: Icons.dangerous_rounded,
        );
      case SafetyLevel.unknown:
        return const _SafetyConfig(
          label: 'Tidak Diketahui',
          color: AppColors.unknownGrey,
          bgColor: AppColors.unknownGreyLight,
          icon: Icons.help_rounded,
        );
    }
  }
}
