import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../models/ingredient.dart';
import '../core/utils/image_utils.dart';

class GeminiService {
  static const String _model = 'gemini-2.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  final String apiKey;

  GeminiService({required this.apiKey});

  Future<AnalysisResult> analyzeIngredients({
    required File imageFile,
    required String resultId,
  }) async {
    final base64Image = await ImageUtils.fileToBase64(imageFile);
    final mimeType = ImageUtils.getMimeType(imageFile.path);

    final prompt = _buildAnalysisPrompt();

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              },
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
    };

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMsg =
          (errorBody['error'] as Map<String, dynamic>?)?['message']
                  as String? ??
              'API Error ${response.statusCode}';
      throw GeminiException(errorMsg, response.statusCode);
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>;
    final parts =
        (candidates.first as Map<String, dynamic>)['content']['parts']
            as List<dynamic>;
    final text = (parts.first as Map<String, dynamic>)['text'] as String;

    return _parseResponse(text, resultId, imageFile.path);
  }

  String _buildAnalysisPrompt() {
    return '''
You are an expert ingredient analyst specializing in medicines, cosmetics, skincare, baby products, health supplements, and personal care products.

Analyze the product label in this image and identify all ingredients listed.

Return ONLY a valid JSON object (no markdown, no code blocks, no extra text) with this exact structure:

{
  "product_name": "Product name if visible, or null",
  "category": "one of: medicine, cosmetics, skincare, baby_product, supplement, personal_care, general",
  "summary": "Brief 2-3 sentence summary in Indonesian about this product and its main purpose",
  "overall_safety_level": "one of: safe, caution, warning, danger, unknown",
  "overall_safety_note": "Explanation of overall safety in Indonesian (2-3 sentences)",
  "recommendation": "Practical usage recommendation in Indonesian",
  "ingredients": [
    {
      "name": "Ingredient name as listed on label",
      "inci": "INCI name if different, or null",
      "function": "Primary function of this ingredient in Indonesian (e.g., Pelembab, Pengawet, Pewarna)",
      "description": "Clear explanation in Indonesian of what this ingredient is and what it does (2-3 sentences)",
      "safety_level": "one of: safe, caution, warning, danger, unknown",
      "safety_reason": "Brief explanation in Indonesian of why this safety level was assigned",
      "benefits": ["benefit 1 in Indonesian", "benefit 2 in Indonesian"],
      "concerns": ["concern 1 in Indonesian if any", "concern 2 in Indonesian if any"],
      "is_common_allergen": true or false,
      "ewg_score": "EWG score 1-10 as string if known, or null"
    }
  ]
}

Safety level guidelines:
- safe: well-studied, generally recognized as safe for most people
- caution: generally safe but may cause issues for sensitive individuals or specific conditions
- warning: known to cause issues for some people, use carefully
- danger: potentially harmful, banned in some countries, or with serious health concerns
- unknown: insufficient data or ingredient unclear from image

If no ingredient list is visible in the image, return:
{
  "product_name": null,
  "category": "general",
  "summary": "Tidak dapat menemukan daftar bahan pada gambar ini.",
  "overall_safety_level": "unknown",
  "overall_safety_note": "Daftar bahan tidak terdeteksi.",
  "recommendation": "Pastikan foto menampilkan label bahan produk dengan jelas.",
  "ingredients": []
}

Analyze ALL visible ingredients. Be thorough and accurate. Return Indonesian language for all text fields.
''';
  }

  AnalysisResult _parseResponse(
      String text, String resultId, String imagePath) {
    String jsonText = text.trim();

    // Extract JSON if wrapped in markdown code blocks
    if (jsonText.contains('```json')) {
      final start = jsonText.indexOf('```json') + 7;
      final end = jsonText.lastIndexOf('```');
      if (end > start) jsonText = jsonText.substring(start, end).trim();
    } else if (jsonText.contains('```')) {
      final start = jsonText.indexOf('```') + 3;
      final end = jsonText.lastIndexOf('```');
      if (end > start) jsonText = jsonText.substring(start, end).trim();
    }

    final Map<String, dynamic> json =
        jsonDecode(jsonText) as Map<String, dynamic>;

    return AnalysisResult(
      id: resultId,
      productName: json['product_name'] as String?,
      category: _parseCategory(json['category'] as String?),
      summary: json['summary'] as String? ?? '',
      overallSafetyNote: json['overall_safety_note'] as String? ?? '',
      overallSafetyLevel:
          _parseSafetyLevel(json['overall_safety_level'] as String?),
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => Ingredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      analyzedAt: DateTime.now(),
      imagePath: imagePath,
      recommendation: json['recommendation'] as String?,
    );
  }

  static ProductCategory _parseCategory(String? value) {
    switch (value?.toLowerCase()) {
      case 'medicine':
        return ProductCategory.medicine;
      case 'cosmetics':
        return ProductCategory.cosmetics;
      case 'skincare':
        return ProductCategory.skincare;
      case 'baby_product':
        return ProductCategory.babyProduct;
      case 'supplement':
        return ProductCategory.supplement;
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

class GeminiException implements Exception {
  final String message;
  final int statusCode;

  const GeminiException(this.message, this.statusCode);

  bool get isAuthError => statusCode == 400 || statusCode == 403;
  bool get isRateLimitError => statusCode == 429;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'GeminiException($statusCode): $message';
}
