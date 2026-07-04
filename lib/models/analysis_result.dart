import 'dart:convert';
import 'chat_message.dart';
import 'ingredient.dart';

enum ProductCategory {
  medicine,
  cosmetics,
  skincare,
  babyProduct,
  supplement,
  personalCare,
  general,
}

class AnalysisResult {
  final String id;
  final String? productName;
  final ProductCategory category;
  final String summary;
  final String overallSafetyNote;
  final SafetyLevel overallSafetyLevel;
  final List<Ingredient> ingredients;
  final DateTime analyzedAt;
  final String? imagePath;
  final String? recommendation;
  final List<ChatMessage> chatMessages;

  const AnalysisResult({
    required this.id,
    this.productName,
    required this.category,
    required this.summary,
    required this.overallSafetyNote,
    required this.overallSafetyLevel,
    required this.ingredients,
    required this.analyzedAt,
    this.imagePath,
    this.recommendation,
    this.chatMessages = const [],
  });

  AnalysisResult copyWith({List<ChatMessage>? chatMessages}) {
    return AnalysisResult(
      id: id,
      productName: productName,
      category: category,
      summary: summary,
      overallSafetyNote: overallSafetyNote,
      overallSafetyLevel: overallSafetyLevel,
      ingredients: ingredients,
      analyzedAt: analyzedAt,
      imagePath: imagePath,
      recommendation: recommendation,
      chatMessages: chatMessages ?? this.chatMessages,
    );
  }

  int get safeCount =>
      ingredients.where((i) => i.safetyLevel == SafetyLevel.safe).length;
  int get cautionCount =>
      ingredients.where((i) => i.safetyLevel == SafetyLevel.caution).length;
  int get warningCount =>
      ingredients.where((i) => i.safetyLevel == SafetyLevel.warning).length;
  int get dangerCount =>
      ingredients.where((i) => i.safetyLevel == SafetyLevel.danger).length;
  int get unknownCount =>
      ingredients.where((i) => i.safetyLevel == SafetyLevel.unknown).length;

  List<Ingredient> get allergens =>
      ingredients.where((i) => i.isCommonAllergen).toList();

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      id: json['id'] as String,
      productName: json['product_name'] as String?,
      category: _parseCategory(json['category'] as String?),
      summary: json['summary'] as String? ?? '',
      overallSafetyNote: json['overall_safety_note'] as String? ?? '',
      overallSafetyLevel:
          _parseSafetyLevel(json['overall_safety_level'] as String?),
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      analyzedAt: DateTime.parse(json['analyzed_at'] as String),
      imagePath: json['image_path'] as String?,
      recommendation: json['recommendation'] as String?,
      chatMessages: (json['chat_messages'] as List<dynamic>? ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_name': productName,
        'category': category.name,
        'summary': summary,
        'overall_safety_note': overallSafetyNote,
        'overall_safety_level': overallSafetyLevel.name,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'analyzed_at': analyzedAt.toIso8601String(),
        'image_path': imagePath,
        'recommendation': recommendation,
        'chat_messages': chatMessages.map((m) => m.toJson()).toList(),
      };

  String toJsonString() => jsonEncode(toJson());

  static AnalysisResult fromJsonString(String jsonStr) =>
      AnalysisResult.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

  static ProductCategory _parseCategory(String? value) {
    switch (value?.toLowerCase()) {
      case 'medicine':
        return ProductCategory.medicine;
      case 'cosmetics':
        return ProductCategory.cosmetics;
      case 'skincare':
        return ProductCategory.skincare;
      case 'babyproduct':
      case 'baby_product':
        return ProductCategory.babyProduct;
      case 'supplement':
        return ProductCategory.supplement;
      case 'personalcare':
      case 'personal_care':
        return ProductCategory.personalCare;
      default:
        return ProductCategory.general;
    }
  }

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
