import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../services/gemini_service.dart';
import '../../../services/product_lookup_service.dart';
import '../../../services/storage_service.dart';
import 'search_event.dart';
import 'search_state.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final StorageService storageService;
  final ProductLookupService _lookupService;
  static const _uuid = Uuid();

  SearchBloc({
    required this.storageService,
    ProductLookupService? lookupService,
  })  : _lookupService = lookupService ?? ProductLookupService(),
        super(const SearchInitial()) {
    on<SearchQuerySubmitted>(_onQuerySubmitted);
    on<SearchResultPicked>(_onResultPicked);
  }

  Future<void> _onQuerySubmitted(
      SearchQuerySubmitted event, Emitter<SearchState> emit) async {
    final query = event.query.trim();
    if (query.isEmpty) return;

    emit(const SearchSearching());

    List<ProductLookupResult> dbResults;
    try {
      dbResults = await _lookupService.searchByName(query);
    } on ProductLookupException {
      dbResults = [];
    }

    if (dbResults.isNotEmpty) {
      emit(SearchResultsFound(dbResults));
      return;
    }

    // Database produk tidak ketemu apa-apa — fallback ke pencarian AI+web.
    final geminiService =
        GeminiService(apiKeys: storageService.getSearchApiKeys());
    String? compositionText;
    try {
      compositionText =
          await geminiService.searchCompositionByWeb(productName: query);
    } on GeminiException catch (e) {
      emit(SearchError(_friendlyGeminiError(e, action: 'mencari')));
      return;
    }

    if (compositionText == null) {
      emit(const SearchNotFound());
      return;
    }

    await _analyzeAndEmit(
      emit,
      ingredientsText: compositionText,
      productNameHint: query,
    );
  }

  Future<void> _onResultPicked(
      SearchResultPicked event, Emitter<SearchState> emit) async {
    await _analyzeAndEmit(
      emit,
      ingredientsText: event.result.ingredientsText,
      productNameHint: event.result.productName,
    );
  }

  Future<void> _analyzeAndEmit(
    Emitter<SearchState> emit, {
    required String ingredientsText,
    String? productNameHint,
  }) async {
    emit(const SearchAnalyzing());
    try {
      final geminiService =
          GeminiService(apiKeys: storageService.getSearchApiKeys());
      final result = await geminiService.analyzeIngredientsFromText(
        ingredientsText: ingredientsText,
        resultId: _uuid.v4(),
        productNameHint: productNameHint,
      );
      await storageService.saveToHistory(result);
      emit(SearchAnalysisSuccess(result));
    } on GeminiException catch (e) {
      emit(SearchError(_friendlyGeminiError(e, action: 'menganalisis')));
    }
  }

  String _friendlyGeminiError(GeminiException e, {required String action}) {
    if (e.isRateLimitError) return e.rateLimitMessage;
    if (e.isServerError) return e.serverErrorMessage;
    return 'Gagal $action: ${e.message}';
  }
}
