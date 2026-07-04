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
