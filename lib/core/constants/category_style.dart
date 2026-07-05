import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_strings.dart';
import '../../models/analysis_result.dart';
import '../../models/ingredient.dart';

extension ProductCategoryStyle on ProductCategory {
  IconData get icon {
    switch (this) {
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
      case ProductCategory.foodBeverage:
        return Icons.restaurant_rounded;
      case ProductCategory.household:
        return Icons.cleaning_services_rounded;
      case ProductCategory.general:
        return Icons.inventory_2_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ProductCategory.medicine:
        return AppColors.primary;
      case ProductCategory.cosmetics:
        return AppColors.categoryCosmetics;
      case ProductCategory.skincare:
        return AppColors.categorySkincare;
      case ProductCategory.babyProduct:
        return AppColors.categoryBabyProduct;
      case ProductCategory.supplement:
        return AppColors.categorySupplement;
      case ProductCategory.personalCare:
        return AppColors.categoryPersonalCare;
      case ProductCategory.foodBeverage:
        return AppColors.categoryFoodBeverage;
      case ProductCategory.household:
        return AppColors.categoryHousehold;
      case ProductCategory.general:
        return AppColors.primary;
    }
  }

  String get label {
    switch (this) {
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
      case ProductCategory.foodBeverage:
        return AppStrings.categoryFoodBeverage;
      case ProductCategory.household:
        return AppStrings.categoryHousehold;
      case ProductCategory.general:
        return AppStrings.categoryGeneral;
    }
  }
}

extension SafetyLevelStyle on SafetyLevel {
  Color get color {
    switch (this) {
      case SafetyLevel.safe:
        return AppColors.safeGreen;
      case SafetyLevel.caution:
        return AppColors.cautionYellow;
      case SafetyLevel.warning:
        return AppColors.warningOrange;
      case SafetyLevel.danger:
        return AppColors.dangerRed;
      case SafetyLevel.unknown:
        return AppColors.unknownGrey;
    }
  }

  Color get lightColor {
    switch (this) {
      case SafetyLevel.safe:
        return AppColors.safeGreenLight;
      case SafetyLevel.caution:
        return AppColors.cautionYellowLight;
      case SafetyLevel.warning:
        return AppColors.warningOrangeLight;
      case SafetyLevel.danger:
        return AppColors.dangerRedLight;
      case SafetyLevel.unknown:
        return AppColors.unknownGreyLight;
    }
  }

  IconData get icon {
    switch (this) {
      case SafetyLevel.safe:
        return Icons.check_circle_rounded;
      case SafetyLevel.caution:
        return Icons.info_rounded;
      case SafetyLevel.warning:
        return Icons.warning_rounded;
      case SafetyLevel.danger:
        return Icons.dangerous_rounded;
      case SafetyLevel.unknown:
        return Icons.help_rounded;
    }
  }
}
