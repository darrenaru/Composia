import '../../../services/product_lookup_service.dart';

abstract class SearchEvent {
  const SearchEvent();
}

class SearchQuerySubmitted extends SearchEvent {
  final String query;
  const SearchQuerySubmitted(this.query);
}

class SearchResultPicked extends SearchEvent {
  final ProductLookupResult result;
  const SearchResultPicked(this.result);
}
