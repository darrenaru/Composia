import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_result.dart';

class StorageService {
  // ponytail: shell branches (Home/History) tetap hidup di background lewat
  // StatefulShellRoute.indexedStack, jadi context.go('/home') tidak lagi
  // membangun ulang layarnya. Notifier ini yang memberi tahu mereka untuk
  // refresh saat riwayat berubah dari layar lain (Recognize/Result/Settings).
  final ValueNotifier<int> historyChanged = ValueNotifier(0);

  // ponytail: key masuk lewat --dart-define saat build (lihat SETUP.md),
  // bukan hardcode, supaya tidak ke-commit ke git. Siapapun yang punya APK
  // hasil build tetap bisa mengekstrak key dari binary — ganti ke server
  // proxy kalau APK ini bakal disebar lebih luas dari sekadar teman dekat.
  // GEMINI_API_KEY_2/_3/_4 opsional — key dari akun Google terpisah, dipakai
  // sebagai fallback kalau key sebelumnya kena rate limit (429).
  static const String _defaultApiKey =
      String.fromEnvironment('GEMINI_API_KEY');
  static const String _fallbackApiKey2 =
      String.fromEnvironment('GEMINI_API_KEY_2');
  static const String _fallbackApiKey3 =
      String.fromEnvironment('GEMINI_API_KEY_3');
  static const String _fallbackApiKey4 =
      String.fromEnvironment('GEMINI_API_KEY_4');
  static const String _fallbackApiKey5 =
      String.fromEnvironment('GEMINI_API_KEY_5');
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
  // Dialokasikan per fitur, tidak dicampur: scan/recognize (pengenalan +
  // ringkasan + analisis bahan) dapat 3 key khusus (1, 4, 5), search dapat
  // 1 key khusus (2), chat dapat 1 key khusus (3). Kalau key khusus
  // search/chat belum diisi, baru fallback ke kumpulan key scan.
  List<String> getScanApiKeys() =>
      [_defaultApiKey, _fallbackApiKey4, _fallbackApiKey5]
          .where((k) => k.isNotEmpty)
          .toList();

  List<String> getSearchApiKeys() {
    if (_fallbackApiKey2.isNotEmpty) return [_fallbackApiKey2];
    return getScanApiKeys();
  }

  List<String> getChatApiKeys() {
    if (_fallbackApiKey3.isNotEmpty) return [_fallbackApiKey3];
    return getScanApiKeys();
  }

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
  List<AnalysisResult> _readAllResults() {
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

  // Produk tanpa nama (mis. label bahan tidak terbaca) tidak ditampilkan
  // di Riwayat, tapi tetap tersimpan supaya ResultScreen bisa menampilkannya
  // sekali langsung setelah scan.
  List<AnalysisResult> getHistory() {
    return _readAllResults()
        .where((r) => r.productName != null && r.productName!.trim().isNotEmpty)
        .toList();
  }

  Future<void> saveToHistory(AnalysisResult result) async {
    final history = _readAllResults();
    history.removeWhere((r) => r.id == result.id);
    history.insert(0, result);

    final trimmed = history.take(_maxHistoryItems).toList();
    final jsonList = trimmed.map((r) => r.toJsonString()).toList();
    await _prefs.setStringList(_historyKey, jsonList);
    historyChanged.value++;
  }

  Future<void> removeFromHistory(String id) async {
    final history = _readAllResults();
    history.removeWhere((r) => r.id == id);
    final jsonList = history.map((r) => r.toJsonString()).toList();
    await _prefs.setStringList(_historyKey, jsonList);
    historyChanged.value++;
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_historyKey);
    historyChanged.value++;
  }

  AnalysisResult? getResultById(String id) {
    try {
      return _readAllResults().firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
