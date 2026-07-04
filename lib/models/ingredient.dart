enum SafetyLevel { safe, caution, warning, danger, unknown }

class Ingredient {
  final String name;
  final String? inci;
  final String function;
  final String description;
  final SafetyLevel safetyLevel;
  final String safetyReason;
  final List<String> concerns;
  final List<String> benefits;
  final bool isCommonAllergen;
  final String? ewgScore;

  const Ingredient({
    required this.name,
    this.inci,
    required this.function,
    required this.description,
    required this.safetyLevel,
    required this.safetyReason,
    this.concerns = const [],
    this.benefits = const [],
    this.isCommonAllergen = false,
    this.ewgScore,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String? ?? '',
      inci: json['inci'] as String?,
      function: json['function'] as String? ?? '',
      description: json['description'] as String? ?? '',
      safetyLevel: _parseSafetyLevel(json['safety_level'] as String?),
      safetyReason: json['safety_reason'] as String? ?? '',
      concerns: (json['concerns'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      benefits: (json['benefits'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isCommonAllergen: json['is_common_allergen'] as bool? ?? false,
      ewgScore: json['ewg_score'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'inci': inci,
        'function': function,
        'description': description,
        'safety_level': safetyLevel.name,
        'safety_reason': safetyReason,
        'concerns': concerns,
        'benefits': benefits,
        'is_common_allergen': isCommonAllergen,
        'ewg_score': ewgScore,
      };

  static SafetyLevel _parseSafetyLevel(String? value) {
    switch (value?.toLowerCase()) {
      case 'safe':
        return SafetyLevel.safe;
      case 'caution':
        return SafetyLevel.caution;
      case 'warning':
        return SafetyLevel.warning;
      case 'danger':
        return SafetyLevel.danger;
      default:
        return SafetyLevel.unknown;
    }
  }
}
