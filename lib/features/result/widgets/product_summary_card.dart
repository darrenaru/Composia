import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../models/analysis_result.dart';
import '../../../models/ingredient.dart';

class ProductSummaryCard extends StatelessWidget {
  final AnalysisResult result;

  const ProductSummaryCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProductInfo(),
        const SizedBox(height: 16),
        _buildSummaryText(),
        const SizedBox(height: 16),
        _buildIngredientStats(),
        if (result.allergens.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildAllergenWarning(),
        ],
        if (result.recommendation != null &&
            result.recommendation!.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildRecommendation(),
        ],
      ],
    );
  }

  Widget _buildProductInfo() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _categoryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(_categoryIcon, color: _categoryColor, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.productName ?? 'Produk Tanpa Nama',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _categoryLabel,
                style: TextStyle(
                  fontSize: 13,
                  color: _categoryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryText() {
    return Text(
      result.summary,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textSecondary,
        height: 1.6,
      ),
    );
  }

  Widget _buildIngredientStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.ingredients.length} Bahan Ditemukan',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildProgressBars(),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (result.safeCount > 0)
                _buildStatChip(
                  result.safeCount,
                  AppStrings.safeIngredients,
                  AppColors.safeGreen,
                ),
              if (result.cautionCount > 0)
                _buildStatChip(
                  result.cautionCount,
                  AppStrings.cautionIngredients,
                  AppColors.cautionYellow,
                ),
              if (result.warningCount > 0)
                _buildStatChip(
                  result.warningCount,
                  AppStrings.warningIngredients,
                  AppColors.warningOrange,
                ),
              if (result.dangerCount > 0)
                _buildStatChip(
                  result.dangerCount,
                  AppStrings.dangerIngredients,
                  AppColors.dangerRed,
                ),
              if (result.unknownCount > 0)
                _buildStatChip(
                  result.unknownCount,
                  AppStrings.unknownIngredients,
                  AppColors.unknownGrey,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBars() {
    final total = result.ingredients.length;
    if (total == 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (result.safeCount > 0)
              Expanded(
                flex: result.safeCount,
                child: Container(color: AppColors.safeGreen),
              ),
            if (result.cautionCount > 0)
              Expanded(
                flex: result.cautionCount,
                child: Container(color: AppColors.cautionYellow),
              ),
            if (result.warningCount > 0)
              Expanded(
                flex: result.warningCount,
                child: Container(color: AppColors.warningOrange),
              ),
            if (result.dangerCount > 0)
              Expanded(
                flex: result.dangerCount,
                child: Container(color: AppColors.dangerRed),
              ),
            if (result.unknownCount > 0)
              Expanded(
                flex: result.unknownCount,
                child: Container(color: AppColors.unknownGrey.withOpacity(0.4)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(int count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAllergenWarning() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningOrangeLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded,
              color: AppColors.warningOrange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mengandung Alergen Umum',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warningOrange,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.allergens.map((a) => a.name).join(', '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendation() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rekomendasi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.recommendation!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData get _categoryIcon {
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

  Color get _categoryColor {
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

  String get _categoryLabel {
    switch (result.category) {
      case ProductCategory.medicine:
        return AppStrings.categoryMedicine;
      case ProductCategory.cosmetics:
        return AppStrings.categoryCosmetics;
      case ProductCategory.skincare:
        return AppStrings.categorySkincare;
      case ProductCategory.babyProduct:
        return AppStrings.categoryBabyProduct;
      case ProductCategory.supplement:
        return AppStrings.categorySupplement;
      case ProductCategory.personalCare:
        return AppStrings.categoryPersonalCare;
      default:
        return AppStrings.categoryGeneral;
    }
  }
}
