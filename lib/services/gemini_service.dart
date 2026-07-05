import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/analysis_result.dart';
import '../models/chat_message.dart';
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
  static const String _model = 'gemini-2.5-flash';
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

  // error.details berisi RetryInfo.retryDelay (mis. "17s") kalau kena
  // limit per-menit — dipakai supaya pesan error bisa kasih tahu berapa
  // lama harus menunggu, bukan cuma "coba lagi" generik.
  GeminiException _exceptionFromResponse(http.Response response) {
    final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
    final error = errorBody['error'] as Map<String, dynamic>?;
    final errorMsg =
        error?['message'] as String? ?? 'API Error ${response.statusCode}';

    int? retryDelaySeconds;
    final details = error?['details'] as List<dynamic>?;
    if (details != null) {
      for (final detail in details) {
        final map = detail as Map<String, dynamic>;
        if ((map['@type'] as String? ?? '').contains('RetryInfo')) {
          final delay = map['retryDelay'] as String?;
          final seconds = double.tryParse(delay?.replaceAll('s', '') ?? '');
          if (seconds != null) retryDelaySeconds = seconds.ceil();
          break;
        }
      }
    }

    return GeminiException(
      errorMsg,
      response.statusCode,
      retryDelaySeconds: retryDelaySeconds,
    );
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
      throw _exceptionFromResponse(response);
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
      throw _exceptionFromResponse(response);
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

IMPORTANT — extracting product_name: only use the actual brand/product name as printed on the packaging (usually short, set in the largest/boldest distinctive font, near a logo). Do NOT use marketing taglines, benefit descriptions, or ingredient callouts as the product name — text like "Centella Asiatica Acne Clear Hydrating & Calming Toner" is a descriptive tagline, not necessarily the registered product name, unless that IS genuinely the printed brand name. Never extract the product name from the ingredients/composition list itself. If you cannot confidently identify a real product name distinct from descriptive/marketing text, return null instead of guessing.

{
  "mode": "direct_analysis",
  "product_name": "Actual product/brand name as printed, or null if not confidently identifiable",
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
      throw _exceptionFromResponse(response);
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

  Future<String> chat({
    required AnalysisResult context,
    required List<ChatMessage> history,
    required String newMessage,
  }) async {
    final contents = [
      {
        'role': 'user',
        'parts': [
          {'text': _buildChatContextPrompt(context)},
        ],
      },
      {
        'role': 'model',
        'parts': [
          {'text': 'Baik, saya siap menjawab pertanyaan tentang produk ini.'},
        ],
      },
      ...history.map((m) => {
            'role': m.role == ChatRole.user ? 'user' : 'model',
            'parts': [
              {'text': m.text},
            ],
          }),
      {
        'role': 'user',
        'parts': [
          {'text': newMessage},
        ],
      },
    ];

    final requestBody = {
      'contents': contents,
      'tools': [
        {'google_search': {}},
      ],
    };
    final response = await _post(requestBody);

    if (response.statusCode != 200) {
      throw _exceptionFromResponse(response);
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>;
    final parts =
        (candidates.first as Map<String, dynamic>)['content']['parts']
            as List<dynamic>;
    return (parts.first as Map<String, dynamic>)['text'] as String;
  }

  String _buildChatContextPrompt(AnalysisResult context) {
    final ingredientLines = context.ingredients
        .map((i) => '- ${i.name} (level: ${i.safetyLevel.name}): ${i.safetyReason}')
        .join('\n');

    return '''
Kamu adalah asisten yang membantu pengguna memahami produk berikut. Gunakan data hasil analisis di bawah ini sebagai konteks utama, dan lengkapi dengan pencarian web kalau pertanyaan pengguna butuh informasi yang lebih luas atau tidak tercakup di data ini.

Nama produk: ${context.productName ?? 'Tidak diketahui'}
Kategori: ${context.category.name}
Ringkasan: ${context.summary}
Catatan keamanan keseluruhan: ${context.overallSafetyNote}
Rekomendasi: ${context.recommendation ?? '-'}

Daftar bahan:
${ingredientLines.isEmpty ? '(tidak ada data bahan)' : ingredientLines}

Jawab dalam Bahasa Indonesia, singkat dan jelas, langsung ke jawabannya. Jangan pernah menyebutkan dari mana informasi berasal (misalnya jangan bilang "berdasarkan data analisis", "menurut hasil pencarian web", "sumber:", dsb) — jawab seolah kamu memang tahu jawabannya.

Kalau pertanyaan pengguna sama sekali tidak berhubungan dengan produk ini (misalnya obrolan umum, topik lain yang tidak nyambung sama sekali dengan produk/bahan/keamanan produk), tolak dengan sopan dan jelaskan bahwa kamu hanya bisa membantu pertanyaan seputar produk ini. Jangan jawab pertanyaan di luar topik tersebut.
''';
  }

  String _buildAnalysisPrompt() {
    return '''
You are an expert ingredient analyst specializing in medicines, cosmetics, skincare, baby products, health supplements, and personal care products.

Analyze the product label in this image and identify all ingredients listed.

IMPORTANT — extracting product_name: only use the actual brand/product name as printed on the packaging (usually short, set in the largest/boldest distinctive font, near a logo). Do NOT use marketing taglines, benefit descriptions, or ingredient callouts as the product name — text like "Centella Asiatica Acne Clear Hydrating & Calming Toner" is a descriptive tagline, not necessarily the registered product name, unless that IS genuinely the printed brand name. Never extract the product name from the ingredients/composition list itself. If you cannot confidently identify a real product name distinct from descriptive/marketing text, return null instead of guessing.

Return ONLY a valid JSON object (no markdown, no code blocks, no extra text) with this exact structure:

{
  "product_name": "Actual product/brand name as printed, or null if not confidently identifiable",
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
  final int? retryDelaySeconds;

  const GeminiException(this.message, this.statusCode, {this.retryDelaySeconds});

  bool get isAuthError => statusCode == 400 || statusCode == 403;
  bool get isRateLimitError => statusCode == 429;
  bool get isServerError => statusCode >= 500;

  // Google mengirim retryDelay (dari RetryInfo di error.details) hanya untuk
  // limit per-menit yang jendelanya pendek — limit harian (RPD) biasanya
  // tidak menyertakan retryDelay karena resetnya di tengah malam Pacific
  // Time, bukan hitungan detik. Kalau tidak ada, pakai pesan generik.
  String get rateLimitMessage => retryDelaySeconds != null
      ? 'Terlalu banyak permintaan. Coba lagi dalam $retryDelaySeconds detik.'
      : 'Terlalu banyak permintaan. Tunggu sebentar dan coba lagi.';

  @override
  String toString() => 'GeminiException($statusCode): $message';
}
