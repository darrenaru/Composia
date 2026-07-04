import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:composia/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getAllergyProfile returns empty list by default', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    expect(storage.getAllergyProfile(), isEmpty);
  });

  test('setAllergyProfile persists lowercase, trimmed, deduped terms', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await storage.setAllergyProfile([' Fragrance ', 'Paraben', 'fragrance']);
    expect(storage.getAllergyProfile(), ['fragrance', 'paraben']);
  });
}
