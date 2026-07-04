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

  test('searchByName returns results from Open Beauty Facts', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'world.openbeautyfacts.org') {
        return http.Response(
          '{"products":[{"product_name":"Sunscreen A","brands":"Merek A","ingredients_text":"Aqua, Zinc Oxide"}]}',
          200,
        );
      }
      return http.Response('{"products":[]}', 200);
    });
    final service = ProductLookupService(client: client);

    final results = await service.searchByName('sunscreen');

    expect(results.length, 1);
    expect(results.first.productName, 'Sunscreen A');
    expect(results.first.ingredientsText, 'Aqua, Zinc Oxide');
  });

  test('searchByName falls back to Open Food Facts when OBF has no results', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'world.openbeautyfacts.org') {
        return http.Response('{"products":[]}', 200);
      }
      return http.Response(
        '{"products":[{"product_name":"Keripik Z","brands":"Merek W","ingredients_text":"Kentang, Garam"}]}',
        200,
      );
    });
    final service = ProductLookupService(client: client);

    final results = await service.searchByName('keripik');

    expect(results.length, 1);
    expect(results.first.productName, 'Keripik Z');
  });

  test('searchByName returns empty list when not found in either database', () async {
    final client = MockClient((request) async => http.Response('{"products":[]}', 200));
    final service = ProductLookupService(client: client);

    final results = await service.searchByName('tidak ada');

    expect(results, isEmpty);
  });

  test('searchByName skips products without ingredients_text', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'world.openbeautyfacts.org') {
        return http.Response(
          '{"products":[{"product_name":"Tanpa Komposisi"},{"product_name":"Ada Komposisi","ingredients_text":"Aqua"}]}',
          200,
        );
      }
      return http.Response('{"products":[]}', 200);
    });
    final service = ProductLookupService(client: client);

    final results = await service.searchByName('produk');

    expect(results.length, 1);
    expect(results.first.productName, 'Ada Komposisi');
  });

  test('searchByName throws ProductLookupException on server error', () async {
    final client = MockClient((request) async => http.Response('Server Error', 500));
    final service = ProductLookupService(client: client);

    expect(
      () => service.searchByName('apapun'),
      throwsA(isA<ProductLookupException>()),
    );
  });
}
