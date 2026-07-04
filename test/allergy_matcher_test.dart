import 'package:flutter_test/flutter_test.dart';
import 'package:composia/core/utils/allergy_matcher.dart';
import 'package:composia/models/ingredient.dart';

Ingredient _ingredient({required String name, String? inci}) {
  return Ingredient(
    name: name,
    inci: inci,
    function: 'test',
    description: 'test',
    safetyLevel: SafetyLevel.safe,
    safetyReason: 'test',
  );
}

void main() {
  test('matches when profile term is substring of ingredient name', () {
    final ing = _ingredient(name: 'Parfum (Fragrance)');
    expect(ingredientMatchesAllergyProfile(ing, ['fragrance']), isTrue);
  });

  test('matches when profile term is substring of inci name', () {
    final ing = _ingredient(name: 'Pengawet', inci: 'Methylparaben');
    expect(ingredientMatchesAllergyProfile(ing, ['paraben']), isTrue);
  });

  test('does not match when profile is empty', () {
    final ing = _ingredient(name: 'Aqua');
    expect(ingredientMatchesAllergyProfile(ing, []), isFalse);
  });

  test('does not match unrelated ingredient', () {
    final ing = _ingredient(name: 'Aqua', inci: 'Water');
    expect(ingredientMatchesAllergyProfile(ing, ['paraben']), isFalse);
  });
}
