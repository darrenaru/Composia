import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/analysis_result.dart';
import '../../result/widgets/safety_badge.dart';

class HistoryPreviewCard extends StatelessWidget {
  final AnalysisResult result;
  final VoidCallback? onTap;

  const HistoryPreviewCard({
    super.key,
    required this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
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
            _buildIcon(),
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
            SafetyBadge(
              level: result.overallSafetyLevel,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _getCategoryColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        _getCategoryIcon(),
        color: _getCategoryColor(),
        size: 24,
      ),
    );
  }

  IconData _getCategoryIcon() {
    switch (result.category) {
      case ProductCategory.medicine:
        return Icons.medication_rounded;
      case ProductCategory.cosmetics:
        return Icons.face_retouching_natural_rounded;
      case ProductCategory.skincare:
        return Icons.spa_rounded;
      case ProductCategory.babyProduct:
        return Icons.child_care_rounded;
      case ProductCategory.supplement:
        return Icons.health_and_safety_rounded;
      case ProductCategory.personalCare:
        return Icons.self_improvement_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  Color _getCategoryColor() {
    switch (result.category) {
      case ProductCategory.medicine:
        return const Color(0xFF6C5CE7);
      case ProductCategory.cosmetics:
        return const Color(0xFFFF7675);
      case ProductCategory.skincare:
        return const Color(0xFF00B894);
      case ProductCategory.babyProduct:
        return const Color(0xFFFDCB6E);
      case ProductCategory.supplement:
        return const Color(0xFF74B9FF);
      case ProductCategory.personalCare:
        return const Color(0xFFE17055);
      default:
        return AppColors.primary;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return 'Hari ini, ${DateFormat('HH:mm').format(dt)}';
    } else if (now.difference(dt).inDays == 1) {
      return 'Kemarin, ${DateFormat('HH:mm').format(dt)}';
    }
    return DateFormat('dd MMM yyyy').format(dt);
  }
}
