import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:composia/models/analysis_result.dart';
import 'package:composia/models/ingredient.dart';
import 'package:composia/services/storage_service.dart';

AnalysisResult _result({required String id, String? productName}) {
  return AnalysisResult(
    id: id,
    productName: productName,
    category: ProductCategory.general,
    summary: 'test',
    overallSafetyNote: 'test',
    overallSafetyLevel: SafetyLevel.unknown,
    ingredients: const [],
    analyzedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getHistory excludes results without a product name', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();

    await storage.saveToHistory(_result(id: '1', productName: 'Sabun Cuci Muka'));
    await storage.saveToHistory(_result(id: '2', productName: null));
    await storage.saveToHistory(_result(id: '3', productName: '   '));

    final history = storage.getHistory();
    expect(history.length, 1);
    expect(history.single.id, '1');
  });

  test('getResultById still finds unnamed results', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();

    await storage.saveToHistory(_result(id: '2', productName: null));

    expect(storage.getResultById('2'), isNotNull);
  });
}
