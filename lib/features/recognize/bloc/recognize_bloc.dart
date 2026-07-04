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
