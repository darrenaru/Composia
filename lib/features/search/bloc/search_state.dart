import '../../../models/analysis_result.dart';
import '../../../services/product_lookup_service.dart';

abstract class SearchState {
  const SearchState();
}

class SearchInitial extends SearchState {
  const SearchInitial();
}

class SearchSearching extends SearchState {
  const SearchSearching();
}

class SearchResultsFound extends SearchState {
  final List<ProductLookupResult> results;
  const SearchResultsFound(this.results);
}

class SearchAnalyzing extends SearchState {
  const SearchAnalyzing();
}

class SearchAnalysisSuccess extends SearchState {
  final AnalysisResult result;
  const SearchAnalysisSuccess(this.result);
}

class SearchNotFound extends SearchState {
  const SearchNotFound();
}

class SearchError extends SearchState {
  final String message;
  const SearchError(this.message);
}
