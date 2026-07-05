import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

  // Unduh APK langsung ke cache dir aplikasi (bukan buka browser) supaya
  // instalasi bisa dipicu langsung dari dalam app lewat open_filex.
  Future<String> downloadApk(
    String url, {
    void Function(double progress)? onProgress,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/composia-update.apk';
    final file = File(filePath);

    final request = http.Request('GET', Uri.parse(url));
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh update (${response.statusCode})');
    }

    final contentLength = response.contentLength ?? 0;
    final sink = file.openWrite();
    var received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (contentLength > 0) onProgress?.call(received / contentLength);
    }
    await sink.close();

    return filePath;
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
