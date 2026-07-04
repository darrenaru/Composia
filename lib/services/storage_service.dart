import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_result.dart';

class StorageService {
  // ponytail: key ditanam agar teman tak perlu isi manual; siapapun yang
  // punya APK ini bisa mengekstrak key. Ganti ke server proxy kalau APK
  // ini bakal disebar lebih luas dari sekadar teman dekat.
  static const String _defaultApiKey =
      'REDACTED_SEE_DART_DEFINE';
  static const String _historyKey = 'composia_history';
  static const String _onboardingKey = 'composia_onboarding_done';
  static const String _languageKey = 'composia_language';
  static const int _maxHistoryItems = 50;

  final SharedPreferences _prefs;

  StorageService._(this._prefs);

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService._(prefs);
  }

  // API Key — ditanam langsung, tidak ada UI untuk isi/ubah manual.
  String getApiKey() => _defaultApiKey;

  static const String _allergyProfileKey = 'composia_allergy_profile';

  // Allergy Profile
  List<String> getAllergyProfile() =>
      _prefs.getStringList(_allergyProfileKey) ?? [];

  Future<void> setAllergyProfile(List<String> terms) {
    final cleaned = terms
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    return _prefs.setStringList(_allergyProfileKey, cleaned);
  }

  // Onboarding
  bool get isOnboardingDone => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> markOnboardingDone() => _prefs.setBool(_onboardingKey, true);

  // Language
  String get language => _prefs.getString(_languageKey) ?? 'id';

  Future<void> setLanguage(String lang) => _prefs.setString(_languageKey, lang);

  // History
  List<AnalysisResult> getHistory() {
    final jsonList = _prefs.getStringList(_historyKey) ?? [];
    return jsonList
        .map((s) {
          try {
            return AnalysisResult.fromJsonString(s);
          } catch (_) {
            return null;
          }
        })
        .whereType<AnalysisResult>()
        .toList()
      ..sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
  }

  Future<void> saveToHistory(AnalysisResult result) async {
    final history = getHistory();
    history.removeWhere((r) => r.id == result.id);
    history.insert(0, result);

    final trimmed = history.take(_maxHistoryItems).toList();
    final jsonList = trimmed.map((r) => r.toJsonString()).toList();
    await _prefs.setStringList(_historyKey, jsonList);
  }

  Future<void> removeFromHistory(String id) async {
    final history = getHistory();
    history.removeWhere((r) => r.id == id);
    final jsonList = history.map((r) => r.toJsonString()).toList();
    await _prefs.setStringList(_historyKey, jsonList);
  }

  Future<void> clearHistory() => _prefs.remove(_historyKey);

  AnalysisResult? getResultById(String id) {
    try {
      return getHistory().firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
