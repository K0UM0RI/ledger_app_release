import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool hasUpdate;
  final String currentVersion;
  final int currentBuildNumber;

  UpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.hasUpdate,
    required this.currentVersion,
    required this.currentBuildNumber,
  });
}

class UpdateService {
  static const String versionJsonUrl =
      'https://raw.githubusercontent.com/K0UM0RI/ledger_app_release/main/version.json';
  static const String githubApiReleasesUrl =
      'https://api.github.com/repos/K0UM0RI/ledger_app_release/releases/latest';

  /// Check if a newer version is available on GitHub
  Future<UpdateInfo> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;

    // 1. Try fetching version.json (Fast, rate-limit free)
    try {
      final json = await _fetchJson(versionJsonUrl);
      if (json != null) {
        final latestVersion = json['version'] as String? ?? currentVersion;
        final latestBuild = json['buildNumber'] as int? ??
            int.tryParse(json['buildNumber']?.toString() ?? '') ??
            0;
        final downloadUrl = json['downloadUrl'] as String? ?? '';
        final releaseNotes =
            json['releaseNotes'] as String? ?? 'New version available.';

        final hasUpdate = _isNewer(
          remoteVersion: latestVersion,
          remoteBuild: latestBuild,
          localVersion: currentVersion,
          localBuild: currentBuildNumber,
        );

        return UpdateInfo(
          latestVersion: latestVersion,
          latestBuildNumber: latestBuild,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          hasUpdate: hasUpdate,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
        );
      }
    } catch (_) {
      // Fallback to GitHub Releases API
    }

    // 2. Fallback to GitHub Releases API
    try {
      final releaseJson = await _fetchJson(githubApiReleasesUrl);
      if (releaseJson != null) {
        final tagName =
            (releaseJson['tag_name'] as String? ?? '').replaceFirst('v', '');
        final releaseNotes = releaseJson['body'] as String? ??
            'Bug fixes and performance improvements.';
        String apkUrl = '';

        final assets = releaseJson['assets'] as List<dynamic>?;
        if (assets != null && assets.isNotEmpty) {
          for (final asset in assets) {
            final name = asset['name'] as String? ?? '';
            if (name.endsWith('.apk')) {
              apkUrl = asset['browser_download_url'] as String? ?? '';
              break;
            }
          }
        }

        // If no assets in release, fallback to raw repo APK
        if (apkUrl.isEmpty && tagName.isNotEmpty) {
          apkUrl =
              'https://raw.githubusercontent.com/K0UM0RI/ledger_app_release/main/ledger-v$tagName.apk';
        }

        final hasUpdate = tagName.isNotEmpty &&
            _isNewer(
              remoteVersion: tagName,
              remoteBuild: 0,
              localVersion: currentVersion,
              localBuild: currentBuildNumber,
            );

        return UpdateInfo(
          latestVersion: tagName.isEmpty ? currentVersion : tagName,
          latestBuildNumber: 0,
          downloadUrl: apkUrl,
          releaseNotes: releaseNotes,
          hasUpdate: hasUpdate,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
        );
      }
    } catch (_) {}

    return UpdateInfo(
      latestVersion: currentVersion,
      latestBuildNumber: currentBuildNumber,
      downloadUrl: '',
      releaseNotes: '',
      hasUpdate: false,
      currentVersion: currentVersion,
      currentBuildNumber: currentBuildNumber,
    );
  }

  /// Start downloading and installing APK
  Stream<OtaEvent> startDownloadAndInstall(String downloadUrl) {
    return OtaUpdate().execute(
      downloadUrl,
      destinationFilename: 'ledger-update.apk',
      androidProviderAuthority: 'com.koumori.ledger.ota_update_provider',
    );
  }

  /// Compare versions
  bool _isNewer({
    required String remoteVersion,
    required int remoteBuild,
    required String localVersion,
    required int localBuild,
  }) {
    if (remoteBuild > 0 && localBuild > 0) {
      return remoteBuild > localBuild;
    }
    return _compareSemanticVersions(remoteVersion, localVersion) > 0;
  }

  int _compareSemanticVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final parts2 = v2.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final len = parts1.length > parts2.length ? parts1.length : parts2.length;
    for (int i = 0; i < len; i++) {
      final p1 = i < parts1.length ? parts1[i] : 0;
      final p2 = i < parts2.length ? parts2[i] : 0;
      if (p1 > p2) return 1;
      if (p1 < p2) return -1;
    }
    return 0;
  }

  Future<Map<String, dynamic>?> _fetchJson(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'LedgerApp');
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        return jsonDecode(content) as Map<String, dynamic>;
      }
    } finally {
      client.close();
    }
    return null;
  }
}
