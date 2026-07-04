import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Satu pill/badge/chip themeable — dipakai untuk filter, status badge,
/// dan kategori. `selected=true` (default) berarti gaya "filled" (badge,
/// kategori); untuk filter yang bisa toggle, kirim `selected` sesuai state.
class AppChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color? backgroundColor;
  final bool selected;
  final bool compact;
  final bool showIcon;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  const AppChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.backgroundColor,
    this.selected = true,
    this.compact = false,
    this.showIcon = true,
    this.onTap,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? color : AppColors.textSecondary;
    final bg = selected
        ? (backgroundColor ?? color.withOpacity(0.12))
        : Colors.transparent;
    final border = selected ? color : AppColors.border;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 14,
          vertical: compact ? 4 : 7,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(compact ? 8 : 20),
          border: Border.all(
            color: selected ? border.withOpacity(0.3) : border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showIcon && icon != null) ...[
              Icon(icon, size: compact ? 12 : 16, color: fg),
              SizedBox(width: compact ? 4 : 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (onDeleted != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onDeleted,
                child: Icon(Icons.close_rounded, size: 14, color: fg),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
