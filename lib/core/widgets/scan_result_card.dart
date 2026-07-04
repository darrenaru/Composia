import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../constants/category_style.dart';
import '../../models/analysis_result.dart';
import '../../features/result/widgets/safety_badge.dart';

/// Baris "hasil scan" — dipakai di Home (riwayat terbaru) dan History
/// (daftar lengkap, dengan mode pilih & swipe-to-delete).
class ScanResultCard extends StatelessWidget {
  final AnalysisResult result;
  final VoidCallback? onTap;
  final bool selectionMode;
  final bool selected;
  final bool dismissible;
  final VoidCallback? onDelete;

  /// Home menampilkan tanggal relatif ("Hari ini, HH:mm"); History sudah
  /// mengelompokkan per tanggal jadi cukup jam saja — set false di sana.
  final bool showRelativeDate;

  const ScanResultCard({
    super.key,
    required this.result,
    this.onTap,
    this.selectionMode = false,
    this.selected = false,
    this.dismissible = false,
    this.onDelete,
    this.showRelativeDate = true,
  });

  String _formatDate(DateTime dt) {
    if (!showRelativeDate) return DateFormat('HH:mm').format(dt);
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return 'Hari ini, ${DateFormat('HH:mm').format(dt)}';
    } else if (now.difference(dt).inDays == 1) {
      return 'Kemarin, ${DateFormat('HH:mm').format(dt)}';
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.textHint,
              ),
              const SizedBox(width: 12),
            ],
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: result.category.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(result.category.icon,
                  color: result.category.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.productName ?? 'Produk Tanpa Nama',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${result.ingredients.length} bahan • ${_formatDate(result.analyzedAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SafetyBadge(level: result.overallSafetyLevel, compact: true),
          ],
        ),
      ),
    );

    if (!dismissible || selectionMode) return card;

    return Dismissible(
      key: Key(result.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.dangerRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: card,
    );
  }
}
