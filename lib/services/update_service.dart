import 'dart:convert';
import 'package:http/http.dart' as http;

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  const UpdateInfo({required this.latestVersion, required this.downloadUrl});
}

class UpdateService {
  static const _releasesUrl =
      'https://api.github.com/repos/darrenaru/Composia/releases/latest';

  final http.Client _client;
  UpdateService({http.Client? client}) : _client = client ?? http.Client();

  // ponytail: distribusi APK di luar Play Store tidak bisa auto-install
  // diam-diam (Android selalu minta konfirmasi tap "Install") — jadi ini
  // cuma mengecek & mengarahkan ke unduhan, bukan update senyap penuh.
  Future<UpdateInfo?> checkForUpdate(String currentVersion) async {
    try {
      final response = await _client.get(Uri.parse(_releasesUrl));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String?;
      if (tagName == null) return null;
      final latestVersion = tagName.startsWith('v')
          ? tagName.substring(1)
          : tagName;

      final assets = json['assets'] as List<dynamic>? ?? [];
      final apkAsset = assets.cast<Map<String, dynamic>>().firstWhere(
            (a) => (a['name'] as String? ?? '').endsWith('.apk'),
            orElse: () => const {},
          );
      final downloadUrl = apkAsset['browser_download_url'] as String?;
      if (downloadUrl == null) return null;

      if (!_isNewer(latestVersion, currentVersion)) return null;

      return UpdateInfo(latestVersion: latestVersion, downloadUrl: downloadUrl);
    } catch (_) {
      return null;
    }
  }

  bool _isNewer(String latest, String current) {
    final latestParts = latest.split('.').map(int.tryParse).toList();
    final currentParts = current.split('.').map(int.tryParse).toList();
    for (var i = 0; i < latestParts.length; i++) {
      final l = latestParts[i] ?? 0;
      final c = i < currentParts.length ? (currentParts[i] ?? 0) : 0;
      if (l != c) return l > c;
    }
    return false;
  }
}
