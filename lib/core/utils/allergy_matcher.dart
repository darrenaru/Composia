import '../../models/ingredient.dart';

bool ingredientMatchesAllergyProfile(
  Ingredient ingredient,
  List<String> profile,
) {
  if (profile.isEmpty) return false;
  final name = ingredient.name.toLowerCase();
  final inci = ingredient.inci?.toLowerCase();
  for (final term in profile) {
    if (term.isEmpty) continue;
    if (name.contains(term)) return true;
    if (inci != null && inci.contains(term)) return true;
  }
  return false;
}
