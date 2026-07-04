# Product Recognition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah jalur baru "Kenali Produk" (scan barcode atau foto kemasan) yang otomatis mencari data komposisi produk, sebagai alternatif di depan alur foto-label-komposisi manual yang sudah ada.

**Architecture:** Fitur baru terisolasi penuh di `lib/features/recognize/` (route `/recognize`), tanpa mengubah `ScanBloc`/`scan_screen.dart` sama sekali. Barcode → Open Beauty/Food Facts, atau foto kemasan → Gemini identify + Gemini web-search grounding, keduanya berujung ke satu titik yang sama: `GeminiService.analyzeIngredientsFromText()`, menghasilkan `AnalysisResult` yang identik strukturnya dengan hasil foto label — jadi ResultScreen/History/Compare/Profil Alergi tidak perlu disentuh.

**Tech Stack:** Flutter/Dart, `flutter_bloc`, `go_router`, package baru `mobile_scanner` (barcode), `http` (sudah ada, dipakai juga untuk Open Beauty/Food Facts dan untuk testing lewat `http/testing.dart`'s `MockClient`).

## Global Constraints

- Tidak ada perubahan ke `ScanBloc`, `scan_screen.dart`, `scan_event.dart`, `scan_state.dart` — jalur manual tetap seperti sekarang.
- Semua kegagalan (barcode tidak ketemu, Gemini identify low-confidence, web search tidak ketemu/tool ditolak, error jaringan) berujung ke state yang menampilkan opsi lanjut, bukan dead-end.
- `imagePath` pada `AnalysisResult` boleh `null` untuk jalur barcode-only (tidak ada foto diambil) — sudah nullable di model, tidak ada UI yang mensyaratkan non-null.
- Sentinel string dari Gemini web-search: persis `TIDAK_DITEMUKAN` (dicek via `isCompositionNotFound`).
- `confidence` dari `identifyPackaging`: salah satu dari `"high"`, `"medium"`, `"low"` — hanya `"high"`/`"medium"` yang lanjut ke pencarian komposisi.

---

### Task 1: ProductLookupService (barcode → Open Beauty/Food Facts)

**Files:**
- Create: `lib/services/product_lookup_service.dart`
- Test: `test/product_lookup_service_test.dart`

**Interfaces:**
- Produces: `class ProductLookupResult { String? productName; String? brand; String ingredientsText; }`, `class ProductLookupException implements Exception { String message; }`, `class ProductLookupService { ProductLookupService({http.Client? client}); Future<ProductLookupResult?> lookupByBarcode(String barcode); }` — dipakai Task 3 (`RecognizeBloc`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/product_lookup_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:composia/services/product_lookup_service.dart';

void main() {
  test('lookupByBarcode returns result from Open Beauty Facts when found', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'world.openbeautyfacts.org') {
        return http.Response(
          '{"status":1,"product":{"product_name":"Sabun X","brands":"Merek Y","ingredients_text":"Aqua, Glycerin"}}',
          200,
        );
      }
      return http.Response('{"status":0}', 200);
    });
    final service = ProductLookupService(client: client);

    final result = await service.lookupByBarcode('12345');

    expect(result, isNotNull);
    expect(result!.productName, 'Sabun X');
    expect(result.brand, 'Merek Y');
    expect(result.ingredientsText, 'Aqua, Glycerin');
  });

  test('lookupByBarcode falls back to Open Food Facts when OBF not found', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'world.openbeautyfacts.org') {
        return http.Response('{"status":0}', 200);
      }
      return http.Response(
        '{"status":1,"product":{"product_name":"Keripik Z","brands":"Merek W","ingredients_text":"Kentang, Garam"}}',
        200,
      );
    });
    final service = ProductLookupService(client: client);

    final result = await service.lookupByBarcode('67890');

    expect(result, isNotNull);
    expect(result!.productName, 'Keripik Z');
  });

  test('lookupByBarcode returns null when not found in either database', () async {
    final client = MockClient((request) async => http.Response('{"status":0}', 200));
    final service = ProductLookupService(client: client);

    final result = await service.lookupByBarcode('00000');

    expect(result, isNull);
  });

  test('lookupByBarcode returns null when ingredients_text is empty', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'world.openbeautyfacts.org') {
        return http.Response(
          '{"status":1,"product":{"product_name":"Tanpa Komposisi","ingredients_text":""}}',
          200,
        );
      }
      return http.Response('{"status":0}', 200);
    });
    final service = ProductLookupService(client: client);

    final result = await service.lookupByBarcode('11111');

    expect(result, isNull);
  });

  test('lookupByBarcode throws ProductLookupException on server error', () async {
    final client = MockClient((request) async => http.Response('Server Error', 500));
    final service = ProductLookupService(client: client);

    expect(
      () => service.lookupByBarcode('99999'),
      throwsA(isA<ProductLookupException>()),
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/product_lookup_service_test.dart`
Expected: FAIL — `package:composia/services/product_lookup_service.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/services/product_lookup_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductLookupResult {
  final String? productName;
  final String? brand;
  final String ingredientsText;

  const ProductLookupResult({
    required this.productName,
    required this.brand,
    required this.ingredientsText,
  });
}

class ProductLookupException implements Exception {
  final String message;
  const ProductLookupException(this.message);

  @override
  String toString() => 'ProductLookupException: $message';
}

class ProductLookupService {
  final http.Client _client;

  ProductLookupService({http.Client? client}) : _client = client ?? http.Client();

  Future<ProductLookupResult?> lookupByBarcode(String barcode) async {
    final fromBeautyFacts = await _tryFetch(
      'https://world.openbeautyfacts.org/api/v2/product/$barcode.json'
      '?fields=product_name,brands,ingredients_text',
    );
    if (fromBeautyFacts != null) return fromBeautyFacts;

    return _tryFetch(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json'
      '?fields=product_name,brands,ingredients_text',
    );
  }

  Future<ProductLookupResult?> _tryFetch(String url) async {
    final response = await _client.get(Uri.parse(url));

    if (response.statusCode != 200) {
      throw ProductLookupException(
          'Gagal menghubungi server (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['status'] != 1) return null;

    final product = json['product'] as Map<String, dynamic>?;
    if (product == null) return null;

    final ingredientsText = product['ingredients_text'] as String?;
    if (ingredientsText == null || ingredientsText.trim().isEmpty) return null;

    return ProductLookupResult(
      productName: product['product_name'] as String?,
      brand: product['brands'] as String?,
      ingredientsText: ingredientsText,
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/product_lookup_service_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/services/product_lookup_service.dart test/product_lookup_service_test.dart
git commit -m "feat: add ProductLookupService for barcode lookup via Open Beauty/Food Facts"
```

---

### Task 2: GeminiService text-based analysis, packaging identification, web-search composition

**Files:**
- Modify: `lib/services/gemini_service.dart`
- Test: `test/gemini_service_composition_test.dart`

**Interfaces:**
- Consumes: `ImageUtils.fileToBase64`/`getMimeType` (existing), `AnalysisResult`/`Ingredient`/`ProductCategory`/`SafetyLevel` (existing models).
- Produces: `bool isCompositionNotFound(String text)`, `class PackagingIdentification { String? productName; String? brand; ProductCategory category; String confidence; }`, `Future<AnalysisResult> GeminiService.analyzeIngredientsFromText({required String ingredientsText, required String resultId, String? productNameHint})`, `Future<PackagingIdentification> GeminiService.identifyPackaging({required File imageFile})`, `Future<String?> GeminiService.searchCompositionByWeb({required String productName, String? brand})` — dipakai Task 3 (`RecognizeBloc`).

- [ ] **Step 1: Write the failing test for the pure sentinel-check helper**

```dart
// test/gemini_service_composition_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:composia/services/gemini_service.dart';

void main() {
  test('isCompositionNotFound returns true for exact sentinel', () {
    expect(isCompositionNotFound('TIDAK_DITEMUKAN'), isTrue);
  });

  test('isCompositionNotFound returns true when sentinel has surrounding whitespace', () {
    expect(isCompositionNotFound('  TIDAK_DITEMUKAN  \n'), isTrue);
  });

  test('isCompositionNotFound returns false for actual composition text', () {
    expect(isCompositionNotFound('Aqua, Glycerin, Parfum'), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/gemini_service_composition_test.dart`
Expected: FAIL — `isCompositionNotFound` undefined.

- [ ] **Step 3: Add the helper, new classes, and new methods to `gemini_service.dart`**

At the top of `lib/services/gemini_service.dart`, right after the imports, add:

```dart
bool isCompositionNotFound(String text) => text.trim() == 'TIDAK_DITEMUKAN';

class PackagingIdentification {
  final String? productName;
  final String? brand;
  final ProductCategory category;
  final String confidence;

  const PackagingIdentification({
    required this.productName,
    required this.brand,
    required this.category,
    required this.confidence,
  });
}
```

Change `_parseResponse`'s signature so `imagePath` accepts `null` (needed for the text-based path). Replace:

```dart
  AnalysisResult _parseResponse(
      String text, String resultId, String imagePath) {
```

with:

```dart
  AnalysisResult _parseResponse(
      String text, String resultId, String? imagePath) {
```

Add the three new methods anywhere inside the `GeminiService` class (e.g. right after `analyzeIngredients`):

```dart
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

    return _parseResponse(text, resultId, null);
  }

  Future<PackagingIdentification> identifyPackaging({
    required File imageFile,
  }) async {
    final base64Image = await ImageUtils.fileToBase64(imageFile);
    final mimeType = ImageUtils.getMimeType(imageFile.path);

    const prompt = '''
You are an expert at identifying consumer products (medicines, cosmetics, skincare, baby products, health supplements, personal care) from their packaging design, logos, and visible text.

Look at this product packaging photo and identify the product.

Return ONLY a valid JSON object (no markdown, no code blocks, no extra text) with this exact structure:

{
  "product_name": "Product name as shown on packaging, or null if unreadable",
  "brand": "Brand name, or null if unreadable",
  "category": "one of: medicine, cosmetics, skincare, baby_product, supplement, personal_care, general",
  "confidence": "one of: high, medium, low"
}

Use "low" confidence if the packaging text is unclear, partially obscured, or you are only guessing from general appearance.
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

    final json = jsonDecode(text.trim()) as Map<String, dynamic>;
    return PackagingIdentification(
      productName: json['product_name'] as String?,
      brand: json['brand'] as String?,
      category: _parseCategory(json['category'] as String?),
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

    final response = await http.post(
      Uri.parse('$_baseUrl?key=$apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    );

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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/gemini_service_composition_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Run full analyzer to confirm the `_parseResponse` signature change didn't break the existing call site**

Run: `flutter analyze lib/services/gemini_service.dart`
Expected: No issues found (the existing call `_parseResponse(text, resultId, imageFile.path)` in `analyzeIngredients` still passes a `String`, which is valid for a `String?` parameter).

- [ ] **Step 6: Commit**

```bash
git add lib/services/gemini_service.dart test/gemini_service_composition_test.dart
git commit -m "feat: add text-based analysis, packaging identification, and web-search composition to GeminiService"
```

---

### Task 3: RecognizeBloc (event, state, bloc)

**Files:**
- Create: `lib/features/recognize/bloc/recognize_event.dart`
- Create: `lib/features/recognize/bloc/recognize_state.dart`
- Create: `lib/features/recognize/bloc/recognize_bloc.dart`

**Interfaces:**
- Consumes: `ProductLookupService`/`ProductLookupResult`/`ProductLookupException` (Task 1), `GeminiService`/`PackagingIdentification`/`GeminiException`/`analyzeIngredientsFromText`/`identifyPackaging`/`searchCompositionByWeb` (Task 2), `StorageService.getApiKey()`/`saveToHistory()` (existing).
- Produces: `RecognizeBloc(required StorageService storageService, ProductLookupService? lookupService)`, events `BarcodeDetected(String code)` / `PackagingPhotoCaptured(File image)`, states `RecognizeInitial`/`RecognizeLookingUp`/`RecognizeIdentifying(File image)`/`RecognizeSearchingComposition(String productName)`/`RecognizeAnalyzing`/`RecognizeSuccess(AnalysisResult result)`/`RecognizeNotFound`/`RecognizeError(String message)` — dipakai Task 4 (`RecognizeScreen`).

- [ ] **Step 1: Create the event file**

```dart
// lib/features/recognize/bloc/recognize_event.dart
import 'dart:io';

abstract class RecognizeEvent {
  const RecognizeEvent();
}

class BarcodeDetected extends RecognizeEvent {
  final String code;
  const BarcodeDetected(this.code);
}

class PackagingPhotoCaptured extends RecognizeEvent {
  final File image;
  const PackagingPhotoCaptured(this.image);
}
```

- [ ] **Step 2: Create the state file**

```dart
// lib/features/recognize/bloc/recognize_state.dart
import 'dart:io';
import '../../../models/analysis_result.dart';

abstract class RecognizeState {
  const RecognizeState();
}

class RecognizeInitial extends RecognizeState {
  const RecognizeInitial();
}

class RecognizeLookingUp extends RecognizeState {
  const RecognizeLookingUp();
}

class RecognizeIdentifying extends RecognizeState {
  final File image;
  const RecognizeIdentifying(this.image);
}

class RecognizeSearchingComposition extends RecognizeState {
  final String productName;
  const RecognizeSearchingComposition(this.productName);
}

class RecognizeAnalyzing extends RecognizeState {
  const RecognizeAnalyzing();
}

class RecognizeSuccess extends RecognizeState {
  final AnalysisResult result;
  const RecognizeSuccess(this.result);
}

class RecognizeNotFound extends RecognizeState {
  const RecognizeNotFound();
}

class RecognizeError extends RecognizeState {
  final String message;
  const RecognizeError(this.message);
}
```

- [ ] **Step 3: Create the bloc**

```dart
// lib/features/recognize/bloc/recognize_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../services/gemini_service.dart';
import '../../../services/product_lookup_service.dart';
import '../../../services/storage_service.dart';
import 'recognize_event.dart';
import 'recognize_state.dart';

class RecognizeBloc extends Bloc<RecognizeEvent, RecognizeState> {
  final StorageService storageService;
  final ProductLookupService _lookupService;
  static const _uuid = Uuid();

  RecognizeBloc({
    required this.storageService,
    ProductLookupService? lookupService,
  })  : _lookupService = lookupService ?? ProductLookupService(),
        super(const RecognizeInitial()) {
    on<BarcodeDetected>(_onBarcodeDetected);
    on<PackagingPhotoCaptured>(_onPackagingPhotoCaptured);
  }

  Future<void> _onBarcodeDetected(
      BarcodeDetected event, Emitter<RecognizeState> emit) async {
    emit(const RecognizeLookingUp());

    ProductLookupResult? lookup;
    try {
      lookup = await _lookupService.lookupByBarcode(event.code);
    } on ProductLookupException catch (e) {
      emit(RecognizeError(e.message));
      return;
    }

    if (lookup == null) {
      emit(const RecognizeNotFound());
      return;
    }

    await _analyzeAndEmit(
      emit,
      ingredientsText: lookup.ingredientsText,
      productNameHint: lookup.productName,
    );
  }

  Future<void> _onPackagingPhotoCaptured(
      PackagingPhotoCaptured event, Emitter<RecognizeState> emit) async {
    emit(RecognizeIdentifying(event.image));
    final geminiService = GeminiService(apiKey: storageService.getApiKey());

    PackagingIdentification identification;
    try {
      identification =
          await geminiService.identifyPackaging(imageFile: event.image);
    } on GeminiException catch (e) {
      emit(RecognizeError(_friendlyGeminiError(e)));
      return;
    }

    final name = identification.productName;
    if (identification.confidence == 'low' ||
        name == null ||
        name.trim().isEmpty) {
      emit(const RecognizeNotFound());
      return;
    }

    emit(RecognizeSearchingComposition(name));
    final compositionText = await geminiService.searchCompositionByWeb(
      productName: name,
      brand: identification.brand,
    );

    if (compositionText == null || compositionText.trim().isEmpty) {
      emit(const RecognizeNotFound());
      return;
    }

    await _analyzeAndEmit(
      emit,
      ingredientsText: compositionText,
      productNameHint: name,
    );
  }

  Future<void> _analyzeAndEmit(
    Emitter<RecognizeState> emit, {
    required String ingredientsText,
    String? productNameHint,
  }) async {
    emit(const RecognizeAnalyzing());
    try {
      final geminiService = GeminiService(apiKey: storageService.getApiKey());
      final resultId = _uuid.v4();
      final result = await geminiService.analyzeIngredientsFromText(
        ingredientsText: ingredientsText,
        resultId: resultId,
        productNameHint: productNameHint,
      );
      await storageService.saveToHistory(result);
      emit(RecognizeSuccess(result));
    } on GeminiException catch (e) {
      emit(RecognizeError(_friendlyGeminiError(e)));
    }
  }

  String _friendlyGeminiError(GeminiException e) {
    if (e.isAuthError) {
      return 'API Key tidak valid. Periksa kembali API Key di Pengaturan.';
    }
    if (e.isRateLimitError) {
      return 'Terlalu banyak permintaan. Tunggu sebentar dan coba lagi.';
    }
    return 'Gagal menganalisis: ${e.message}';
  }
}
```

- [ ] **Step 4: Verify it builds**

Run: `flutter analyze lib/features/recognize/bloc/`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add lib/features/recognize/bloc/
git commit -m "feat: add RecognizeBloc orchestrating barcode and packaging-photo recognition"
```

---

### Task 4: RecognizeScreen UI + mobile_scanner dependency

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/recognize/recognize_screen.dart`

**Interfaces:**
- Consumes: `RecognizeBloc`/events/states (Task 3), `ImagePicker` (existing package, same pattern as `ScanBloc`'s camera/gallery capture).
- Produces: `class RecognizeScreen extends StatefulWidget` (no constructor params — bloc is provided via `BlocProvider` at the router level in Task 5).

- [ ] **Step 1: Add the `mobile_scanner` dependency**

In `pubspec.yaml`, add this line under `dependencies:` (next to `image_picker`):

```yaml
  mobile_scanner: ^5.2.3
```

- [ ] **Step 2: Fetch the dependency**

Run: `flutter pub get`
Expected: `mobile_scanner` and its transitive deps resolve without errors.

- [ ] **Step 3: Create the screen**

```dart
// lib/features/recognize/recognize_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import 'bloc/recognize_bloc.dart';
import 'bloc/recognize_event.dart';
import 'bloc/recognize_state.dart';

class RecognizeScreen extends StatefulWidget {
  const RecognizeScreen({super.key});

  @override
  State<RecognizeScreen> createState() => _RecognizeScreenState();
}

class _RecognizeScreenState extends State<RecognizeScreen> {
  bool _barcodeHandled = false;

  void _onBarcodeDetect(BarcodeCapture capture) {
    if (_barcodeHandled) return;
    final code =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null) return;
    _barcodeHandled = true;
    context.read<RecognizeBloc>().add(BarcodeDetected(code));
  }

  Future<void> _pickPackagingPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked != null && mounted) {
      context
          .read<RecognizeBloc>()
          .add(PackagingPhotoCaptured(File(picked.path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Kenali Produk'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: BlocConsumer<RecognizeBloc, RecognizeState>(
        listener: (context, state) {
          if (state is RecognizeSuccess) {
            context.pushReplacement('/result/${state.result.id}');
          }
        },
        builder: (context, state) {
          if (state is RecognizeNotFound) {
            return _buildMessage(
              icon: Icons.search_off_rounded,
              iconColor: AppColors.textHint,
              message: 'Produk tidak dapat dikenali otomatis.',
            );
          }
          if (state is RecognizeError) {
            return _buildMessage(
              icon: Icons.error_outline_rounded,
              iconColor: AppColors.dangerRed,
              message: state.message,
            );
          }
          if (state is RecognizeLookingUp ||
              state is RecognizeIdentifying ||
              state is RecognizeSearchingComposition ||
              state is RecognizeAnalyzing) {
            return _buildLoading(state);
          }
          return _buildScanner();
        },
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(onDetect: _onBarcodeDetect),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Arahkan kamera ke barcode kemasan produk',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(RecognizeState state) {
    var label = 'Memproses...';
    if (state is RecognizeLookingUp) label = 'Mencari data produk...';
    if (state is RecognizeIdentifying) label = 'Mengenali kemasan...';
    if (state is RecognizeSearchingComposition) {
      label = 'Mencari komposisi ${state.productName}...';
    }
    if (state is RecognizeAnalyzing) label = 'Menganalisis bahan...';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => _pickPackagingPhoto(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Foto Kemasan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.push('/scan'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Foto Komposisi Manual'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Verify it builds**

Run: `flutter analyze lib/features/recognize/recognize_screen.dart`
Expected: No issues found.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/features/recognize/recognize_screen.dart
git commit -m "feat: add RecognizeScreen with barcode scanner and packaging-photo capture"
```

---

### Task 5: Router wiring and Home entry point

**Files:**
- Modify: `lib/router/app_router.dart`
- Modify: `lib/features/home/home_screen.dart`

**Interfaces:**
- Consumes: `RecognizeBloc` (Task 3), `RecognizeScreen` (Task 4).

- [ ] **Step 1: Add the route**

In `lib/router/app_router.dart`, add the imports:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
```

(already imported — verify, don't duplicate) and:

```dart
import '../features/recognize/bloc/recognize_bloc.dart';
import '../features/recognize/recognize_screen.dart';
```

Add the route (e.g. right after `/scan`):

```dart
      GoRoute(
        path: '/recognize',
        builder: (context, state) => BlocProvider(
          create: (_) => RecognizeBloc(storageService: storageService),
          child: const RecognizeScreen(),
        ),
      ),
```

- [ ] **Step 2: Repoint Home's scan entry point**

In `lib/features/home/home_screen.dart`, find `_pushScan` and change the route it pushes:

```dart
  void _pushScan(BuildContext context) {
    context.push('/recognize').then((_) => _loadHistory());
  }
```

(This single helper is already used by both the FAB and the category chips, from the earlier allergy/compare work this session — no other call site needs changing.)

- [ ] **Step 3: Verify it builds**

Run: `flutter analyze lib/router/app_router.dart lib/features/home/home_screen.dart`
Expected: No issues found.

- [ ] **Step 4: Commit**

```bash
git add lib/router/app_router.dart lib/features/home/home_screen.dart
git commit -m "feat: wire /recognize route and repoint Home's scan entry point"
```

---

### Task 6: Manual verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: all tests pass (8 tests from earlier this session + 5 from Task 1 + 3 from Task 2 = 16 total).

- [ ] **Step 2: Build and install debug APK on connected device**

Run: `flutter run -d <device-id> --dart-define=GEMINI_API_KEY=<your_key>` (or use `./run_local.sh` created earlier this session, which already includes the key).

- [ ] **Step 3: Verify the barcode path**

- Dari Home, tap "Scan Produk" atau kategori mana pun → harus masuk ke layar "Kenali Produk" (bukan langsung ke foto komposisi).
- Arahkan kamera ke barcode produk kosmetik/skincare bermerek (kemungkinan besar ada di Open Beauty Facts).
- Expected: muncul "Mencari data produk..." → "Menganalisis bahan..." → navigasi ke Hasil Analisis dengan data bahan yang masuk akal.
- Coba juga barcode acak/tidak terdaftar → expected: muncul pesan "Produk tidak dapat dikenali otomatis" dengan tombol "Foto Kemasan" dan "Foto Komposisi Manual".

- [ ] **Step 4: Verify the packaging-photo path**

- Dari layar "Produk tidak dapat dikenali otomatis" (atau tap "Foto Kemasan" langsung dari layar scanner), foto kemasan produk yang jelas mereknya.
- Expected: "Mengenali kemasan..." → "Mencari komposisi [nama produk]..." → salah satu dari: berhasil ke Hasil Analisis, ATAU "Produk tidak dapat dikenali otomatis" kalau web search tidak ketemu/tool `google_search` ditolak API (verifikasi ini **tidak** crash, hanya fallback dengan pesan).

- [ ] **Step 5: Verify the manual fallback still works untouched**

- Dari layar "Kenali Produk", tap "Foto Komposisi Manual" → harus masuk ke layar Scan yang lama persis seperti sebelum fitur ini ada (foto label komposisi langsung).

- [ ] **Step 6: Final commit (if any manual fixes were needed)**

```bash
git add -A
git commit -m "fix: address issues found during manual verification of product recognition"
```

(Skip this step if no changes were needed.)
