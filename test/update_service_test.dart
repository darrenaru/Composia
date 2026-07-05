import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:composia/services/update_service.dart';

void main() {
  test('checkForUpdate returns UpdateInfo when a newer release exists', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"tag_name":"v1.2.0","assets":[{"name":"app-release.apk","browser_download_url":"https://example.com/app-release.apk"}]}',
        200,
      );
    });
    final service = UpdateService(client: client);

    final info = await service.checkForUpdate('1.0.0');

    expect(info, isNotNull);
    expect(info!.latestVersion, '1.2.0');
    expect(info.downloadUrl, 'https://example.com/app-release.apk');
  });

  test('checkForUpdate returns null when already on latest version', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"tag_name":"v1.0.0","assets":[{"name":"app-release.apk","browser_download_url":"https://example.com/app-release.apk"}]}',
        200,
      );
    });
    final service = UpdateService(client: client);

    final info = await service.checkForUpdate('1.0.0');

    expect(info, isNull);
  });

  test('checkForUpdate returns null when current version is newer', () async {
    final client = MockClient((request) async {
      return http.Response(
        '{"tag_name":"v1.0.0","assets":[{"name":"app-release.apk","browser_download_url":"https://example.com/app-release.apk"}]}',
        200,
      );
    });
    final service = UpdateService(client: client);

    final info = await service.checkForUpdate('1.1.0');

    expect(info, isNull);
  });

  test('checkForUpdate returns null on server error', () async {
    final client = MockClient((request) async => http.Response('', 500));
    final service = UpdateService(client: client);

    final info = await service.checkForUpdate('1.0.0');

    expect(info, isNull);
  });

  test('checkForUpdate returns null when no apk asset is attached', () async {
    final client = MockClient((request) async {
      return http.Response('{"tag_name":"v1.2.0","assets":[]}', 200);
    });
    final service = UpdateService(client: client);

    final info = await service.checkForUpdate('1.0.0');

    expect(info, isNull);
  });
}
