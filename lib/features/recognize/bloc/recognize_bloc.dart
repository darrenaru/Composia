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
    on<PhotoTaken>(_onPhotoTaken);
  }

  Future<void> _onPhotoTaken(
      PhotoTaken event, Emitter<RecognizeState> emit) async {
    emit(const RecognizeAnalyzingPhoto());
    final geminiService = GeminiService(apiKeys: storageService.getApiKeys());

    PhotoAnalysisResult photoResult;
    try {
      photoResult = await geminiService.analyzePhoto(
        imageFile: event.image,
        resultId: _uuid.v4(),
      );
    } on GeminiException catch (e) {
      emit(RecognizeError(_friendlyGeminiError(e)));
      return;
    }

    if (photoResult is DirectAnalysisResult) {
      await storageService.saveToHistory(photoResult.result);
      emit(RecognizeSuccess(photoResult.result));
      return;
    }

    final needsLookup = photoResult as NeedsLookupResult;

    ProductLookupResult? lookup;
    final barcodeDigits = needsLookup.barcodeDigits;
    if (barcodeDigits != null && barcodeDigits.trim().isNotEmpty) {
      try {
        lookup = await _lookupService.lookupByBarcode(barcodeDigits.trim());
      } on ProductLookupException {
        lookup = null;
      }
    }

    String? compositionText;
    String? productNameHint;

    if (lookup != null) {
      compositionText = lookup.ingredientsText;
      productNameHint = lookup.productName ?? needsLookup.productName;
    } else if (needsLookup.confidence != 'low' &&
        needsLookup.productName != null &&
        needsLookup.productName!.trim().isNotEmpty) {
      emit(RecognizeSearchingComposition(needsLookup.productName!));
      compositionText = await geminiService.searchCompositionByWeb(
        productName: needsLookup.productName!,
        brand: needsLookup.brand,
      );
      productNameHint = needsLookup.productName;
    }

    if (compositionText == null || compositionText.trim().isEmpty) {
      emit(const RecognizeNotFound());
      return;
    }

    await _analyzeAndEmit(
      emit,
      ingredientsText: compositionText,
      productNameHint: productNameHint,
    );
  }

  Future<void> _analyzeAndEmit(
    Emitter<RecognizeState> emit, {
    required String ingredientsText,
    String? productNameHint,
  }) async {
    emit(const RecognizeAnalyzing());
    try {
      final geminiService = GeminiService(apiKeys: storageService.getApiKeys());
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
