import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../models/ingredient.dart';
import '../core/utils/image_utils.dart';

bool isCompositionNotFound(String text) => text.trim() == 'TIDAK_DITEMUKAN';

sealed class PhotoAnalysisResult {}

class DirectAnalysisResult extends PhotoAnalysisResult {
  final AnalysisResult result;
  DirectAnalysisResult(this.result);
}

class NeedsLookupResult extends PhotoAnalysisResult {
  final String? productName;
  final String? brand;
  final ProductCategory category;
  final String? barcodeDigits;
  final String confidence;

  NeedsLookupResult({
    required this.productName,
    required this.brand,
    required this.category,
    required this.barcodeDigits,
    required this.confidence,
  });
}

class GeminiService {
  static const String _model = 'gemini-3.5-flash';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  final List<String> apiKeys;

  GeminiService({required this.apiKeys})
      : assert(apiKeys.isNotEmpty, 'apiKeys must not be empty');

  // Coba key berikutnya kalau kena rate limit (429) — key lain biasanya
  // dari akun Google terpisah sehingga limitnya independen. Error selain
  // 429 langsung dikembalikan tanpa retry karena bukan soal kuota.
  Future<http.Response> _post(Map<String, dynamic> requestBody) async {
    http.Response? lastResponse;
    for (final key in apiKeys) {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$key'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );
      if (response.statusCode != 429) return response;
      lastResponse = response;
    }
    return lastResponse!;
  }

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

    final response = await _post(requestBody);

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

  Future<AnalysisResult> analyzeIngredientsFromText({
    required String ingredientsText,
    required String resultId,
    String? productNameHint,
  }) async {
    final hintLine = productNameHint != null && productNameHint.isNotEmpty
        ? 'Product name (extra context, may help but verify against the text below): $productNameHint\n\n'
        : '';
    final fullPrompt =
        '$hintLine${_buildAnalysisPrompt()}\n\nHere is the raw ingredients list text to analyze (not an image):\n$ingredientsText';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': fullPrompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
    };

    final response = await _post(requestBody);

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

    return _parseResponse(text, resultId, null);
  }

  Future<PhotoAnalysisResult> analyzePhoto({
    required File imageFile,
    required String resultId,
  }) async {
    final base64Image = await ImageUtils.fileToBase64(imageFile);
    final mimeType = ImageUtils.getMimeType(imageFile.path);

    const prompt = '''
You are an expert at analyzing consumer product photos (medicines, cosmetics, skincare, baby products, health supplements, personal care).

Look at this photo carefully. It may show either:
(A) A visible ingredients/composition list (label text), or
(B) Product packaging/branding without a visible composition list (logo, brand name, product shape, printed barcode digits, etc).

Decide which case applies, using all visible clues: OCR text, brand/logo recognition, product shape and packaging design, and any barcode digits printed as text near a barcode. Do not attempt to decode the barcode's bar pattern itself — only read printed digits if legible as text.

Return ONLY a valid JSON object (no markdown, no code blocks, no extra text).

If case (A) — a composition/ingredients list is visible and readable, use this structure:
{
  "mode": "direct_analysis",
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

If case (B) — no readable composition list, only packaging/branding visible, use this structure instead:
{
  "mode": "needs_lookup",
  "product_name": "Product name as shown on packaging, or null if unreadable",
  "brand": "Brand name, or null if unreadable",
  "category": "one of: medicine, cosmetics, skincare, baby_product, supplement, personal_care, general",
  "barcode_digits": "printed barcode number if visible as text, or null",
  "confidence": "one of: high, medium, low"
}

Use "low" confidence in case (B) if the packaging text is unclear, partially obscured, or you are only guessing from general appearance.
''';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {
              'inline_data': {'mime_type': mimeType, 'data': base64Image},
            },
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
      },
    };

    final response = await _post(requestBody);

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

    final json = jsonDecode(text.trim()) as Map<String, dynamic>;
    if (json['mode'] == 'direct_analysis') {
      return DirectAnalysisResult(_parseResponse(text, resultId, imageFile.path));
    }

    return NeedsLookupResult(
      productName: json['product_name'] as String?,
      brand: json['brand'] as String?,
      category: _parseCategory(json['category'] as String?),
      barcodeDigits: json['barcode_digits'] as String?,
      confidence: json['confidence'] as String? ?? 'low',
    );
  }

  Future<String?> searchCompositionByWeb({
    required String productName,
    String? brand,
  }) async {
    final productLabel =
        brand != null && brand.isNotEmpty ? '$brand $productName' : productName;

    final prompt =
        'Cari daftar komposisi/ingredients lengkap dari produk berikut: $productLabel. '
        'Jika kamu menemukan sumber yang bisa dipercaya (situs resmi produsen, database produk, atau retailer terpercaya), '
        'balas HANYA dengan daftar bahan mentah apa adanya (dipisah koma), tanpa penjelasan tambahan. '
        'Jika tidak menemukan sumber terpercaya, balas PERSIS dengan teks ini saja: TIDAK_DITEMUKAN';

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'tools': [
        {'google_search': {}},
      ],
    };

    final response = await _post(requestBody);

    if (response.statusCode != 200) return null;

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return null;

    final parts = (candidates.first as Map<String, dynamic>)['content']
        ?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return null;

    final text = (parts.first as Map<String, dynamic>)['text'] as String? ?? '';
    if (text.trim().isEmpty || isCompositionNotFound(text)) return null;

    return text.trim();
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
      String text, String resultId, String? imagePath) {
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
