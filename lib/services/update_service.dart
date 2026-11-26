import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'apk_delta.dart';

class DeviceUpdateInfo {
  final String primaryAbi;
  final List<String> supportedAbis;
  final String sourceApkPath;
  final String installedApkSha256;

  const DeviceUpdateInfo({
    this.primaryAbi = '',
    this.supportedAbis = const [],
    this.sourceApkPath = '',
    this.installedApkSha256 = '',
  });
}

class UpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String downloadUrl;
  final String releaseNotes;
  final bool hasUpdate;
  final String currentVersion;
  final int currentBuildNumber;
  final String selectedAbi;
  final int? fullApkSizeBytes;
  final String? fullApkSha256;
  final String? deltaPatchUrl;
  final int? deltaPatchSizeBytes;
  final String? deltaTargetSha256;
  final String? sourceApkPath;

  UpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.hasUpdate,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.selectedAbi = '',
    this.fullApkSizeBytes,
    this.fullApkSha256,
    this.deltaPatchUrl,
    this.deltaPatchSizeBytes,
    this.deltaTargetSha256,
    this.sourceApkPath,
  });

  bool get hasDeltaPatch =>
      deltaPatchUrl != null &&
      deltaPatchUrl!.isNotEmpty &&
      deltaTargetSha256 != null &&
      deltaTargetSha256!.isNotEmpty &&
      sourceApkPath != null &&
      sourceApkPath!.isNotEmpty;

  int? get savedBytes {
    if (!hasDeltaPatch ||
        fullApkSizeBytes == null ||
        deltaPatchSizeBytes == null) {
      return null;
    }
    final diff = fullApkSizeBytes! - deltaPatchSizeBytes!;
    return diff > 0 ? diff : null;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

enum UpdateStage {
  downloadingPatch,
  applyingPatch,
  verifying,
  downloadingFull,
  installing,
  permissionRequired,
  error,
}

class UpdateProgress {
  final UpdateStage stage;
  final double progress; // 0.0 to 1.0 (negative = indeterminate)
  final String message;

  const UpdateProgress({
    required this.stage,
    required this.progress,
    required this.message,
  });
}

class UpdateService {
  static const String versionJsonUrl =
      'https://raw.githubusercontent.com/K0UM0RI/ledger_app_release/main/version.json';
  static const String githubApiReleasesUrl =
      'https://api.github.com/repos/K0UM0RI/ledger_app_release/releases/latest';
  static const MethodChannel _channel =
      MethodChannel('com.koumori.ledger/updater');

  /// Fetches native Android ABI + installed APK path + SHA-256.
  Future<DeviceUpdateInfo> getDeviceUpdateInfo() async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
        'getDeviceUpdateInfo',
      );
      if (raw == null) return const DeviceUpdateInfo();
      final abis = (raw['supportedAbis'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      return DeviceUpdateInfo(
        primaryAbi: raw['primaryAbi'] as String? ??
            (abis.isNotEmpty ? abis.first : ''),
        supportedAbis: abis,
        sourceApkPath: raw['sourceApkPath'] as String? ?? '',
        installedApkSha256:
            (raw['installedApkSha256'] as String? ?? '').toLowerCase(),
      );
    } catch (_) {
      return const DeviceUpdateInfo();
    }
  }

  Future<String?> computeFileSha256(String path) async {
    try {
      final hash = await _channel.invokeMethod<String>(
        'computeFileSha256',
        {'path': path},
      );
      return hash?.toLowerCase();
    } catch (_) {
      return null;
    }
  }

  Future<String> installLocalApk(String path) async {
    final res = await _channel.invokeMethod<String>(
      'installApk',
      {'path': path},
    );
    return res ?? 'OK';
  }

  /// Parses `version.json` and selects the best split APK + matching delta patch
  /// for the current device. Pure & unit-testable.
  static UpdateInfo parseVersionJson({
    required Map<String, dynamic> json,
    required String currentVersion,
    required int currentBuildNumber,
    DeviceUpdateInfo device = const DeviceUpdateInfo(),
  }) {
    final latestVersion = json['version'] as String? ?? currentVersion;
    final latestBuild = json['buildNumber'] is int
        ? json['buildNumber'] as int
        : int.tryParse(json['buildNumber']?.toString() ?? '') ?? 0;
    final releaseNotes =
        json['releaseNotes'] as String? ?? 'New version available.';

    String downloadUrl = json['downloadUrl'] as String? ?? '';
    String selectedAbi = '';
    int? fullApkSizeBytes;
    String? fullApkSha256;

    // 1. Select best matching ABI split APK if available
    final apksMap = json['apks'];
    if (apksMap is Map) {
      Map<String, dynamic>? chosenEntry;
      for (final abi in device.supportedAbis) {
        final candidate = apksMap[abi];
        if (candidate is Map) {
          selectedAbi = abi;
          chosenEntry = Map<String, dynamic>.from(candidate);
          break;
        }
      }
      // Fallback to arm64-v8a or first entry if device ABI wasn't listed
      if (chosenEntry == null && apksMap.isNotEmpty) {
        if (apksMap['arm64-v8a'] is Map) {
          selectedAbi = 'arm64-v8a';
          chosenEntry = Map<String, dynamic>.from(apksMap['arm64-v8a'] as Map);
        } else {
          final firstKey = apksMap.keys.first.toString();
          if (apksMap[firstKey] is Map) {
            selectedAbi = firstKey;
            chosenEntry = Map<String, dynamic>.from(apksMap[firstKey] as Map);
          }
        }
      }
      if (chosenEntry != null) {
        final abiUrl = chosenEntry['url'] as String? ?? '';
        if (abiUrl.isNotEmpty) {
          downloadUrl = abiUrl;
        }
        fullApkSizeBytes = (chosenEntry['size'] as num?)?.toInt();
        fullApkSha256 = (chosenEntry['sha256'] as String?)?.toLowerCase();
      }
    }

    // 2. Match a binary delta patch if installed APK SHA-256 matches baseSha256
    String? deltaPatchUrl;
    int? deltaPatchSizeBytes;
    String? deltaTargetSha256;

    final patchesRaw = json['patches'];
    if (patchesRaw is List &&
        device.installedApkSha256.isNotEmpty &&
        device.sourceApkPath.isNotEmpty) {
      for (final item in patchesRaw) {
        if (item is! Map) continue;
        final patchAbi = item['abi'] as String? ?? '';
        final baseSha = (item['baseSha256'] as String? ?? '').toLowerCase();
        final targetSha = (item['targetSha256'] as String? ?? '').toLowerCase();
        final patchUrl = item['url'] as String? ?? '';
        final patchSize = (item['size'] as num?)?.toInt();

        final abiMatches =
            selectedAbi.isEmpty || patchAbi.isEmpty || patchAbi == selectedAbi;
        if (abiMatches &&
            baseSha.isNotEmpty &&
            baseSha == device.installedApkSha256 &&
            targetSha.isNotEmpty &&
            patchUrl.isNotEmpty) {
          deltaPatchUrl = patchUrl;
          deltaPatchSizeBytes = patchSize;
          deltaTargetSha256 = targetSha;
          break;
        }
      }
    }

    final hasUpdate = isNewerVersion(
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
      selectedAbi: selectedAbi,
      fullApkSizeBytes: fullApkSizeBytes,
      fullApkSha256: fullApkSha256,
      deltaPatchUrl: deltaPatchUrl,
      deltaPatchSizeBytes: deltaPatchSizeBytes,
      deltaTargetSha256: deltaTargetSha256,
      sourceApkPath: device.sourceApkPath,
    );
  }

  /// Check if a newer version is available on GitHub.
  Future<UpdateInfo> checkForUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    final device = await getDeviceUpdateInfo();

    // 1. Try fetching version.json (Fast, rate-limit free)
    try {
      final json = await _fetchJson(versionJsonUrl);
      if (json != null) {
        return parseVersionJson(
          json: json,
          currentVersion: currentVersion,
          currentBuildNumber: currentBuildNumber,
          device: device,
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
          for (final abi in device.supportedAbis) {
            for (final asset in assets) {
              final name = asset['name'] as String? ?? '';
              if (name.endsWith('.apk') && name.contains(abi)) {
                apkUrl = asset['browser_download_url'] as String? ?? '';
                break;
              }
            }
            if (apkUrl.isNotEmpty) break;
          }
          if (apkUrl.isEmpty) {
            for (final asset in assets) {
              final name = asset['name'] as String? ?? '';
              if (name.endsWith('.apk')) {
                apkUrl = asset['browser_download_url'] as String? ?? '';
                break;
              }
            }
          }
        }

        if (apkUrl.isEmpty && tagName.isNotEmpty) {
          apkUrl =
              'https://raw.githubusercontent.com/K0UM0RI/ledger_app_release/main/ledger-v$tagName.apk';
        }

        final hasUpdate = tagName.isNotEmpty &&
            isNewerVersion(
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
          selectedAbi: device.primaryAbi,
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

  /// Smart updater: attempts a small binary delta patch when available,
  /// verifies SHA-256, and automatically falls back to the full split APK if needed.
  Stream<UpdateProgress> startSmartUpdate(UpdateInfo info) {
    final controller = StreamController<UpdateProgress>();

    () async {
      try {
        final cacheDir = await getTemporaryDirectory();
        final outputApkFile = File('${cacheDir.path}/ledger-update.apk');
        if (outputApkFile.existsSync()) {
          outputApkFile.deleteSync();
        }

        bool apkReady = false;

        // --- PATH A: BINARY DELTA PATCH ---
        if (info.hasDeltaPatch) {
          final patchFile = File('${cacheDir.path}/ledger-patch.ldgpatch');
          try {
            if (patchFile.existsSync()) patchFile.deleteSync();

            await _downloadFile(
              url: info.deltaPatchUrl!,
              destination: patchFile,
              expectedBytes: info.deltaPatchSizeBytes,
              onProgress: (fraction, received, total) {
                final pct = (fraction * 100).clamp(0, 100).toInt();
                final sizeLabel = total > 0
                    ? '${UpdateInfo.formatBytes(received)} / ${UpdateInfo.formatBytes(total)}'
                    : UpdateInfo.formatBytes(received);
                controller.add(UpdateProgress(
                  stage: UpdateStage.downloadingPatch,
                  progress: fraction * 0.70,
                  message: 'Downloading delta patch: $pct% ($sizeLabel)',
                ));
              },
            );

            controller.add(const UpdateProgress(
              stage: UpdateStage.applyingPatch,
              progress: -1,
              message: 'Applying binary patch to installed APK...',
            ));

            final sourcePath = info.sourceApkPath!;
            final patchPath = patchFile.path;
            final outPath = outputApkFile.path;

            await Isolate.run(() {
              final oldBytes = File(sourcePath).readAsBytesSync();
              final patchBytes = File(patchPath).readAsBytesSync();
              final newBytes = ApkDelta.applyPatch(oldBytes, patchBytes);
              File(outPath).writeAsBytesSync(newBytes, flush: true);
            });

            controller.add(const UpdateProgress(
              stage: UpdateStage.verifying,
              progress: 0.92,
              message: 'Verifying reconstructed APK checksum...',
            ));

            final actualSha = await computeFileSha256(outputApkFile.path);
            if (actualSha != null &&
                actualSha.toLowerCase() ==
                    info.deltaTargetSha256!.toLowerCase()) {
              apkReady = true;
            } else {
              // Checksum mismatch -> fallback cleanly to full split APK
              if (outputApkFile.existsSync()) outputApkFile.deleteSync();
            }
          } catch (_) {
            // Any patch error -> fallback cleanly to full split APK
            if (outputApkFile.existsSync()) outputApkFile.deleteSync();
          } finally {
            if (patchFile.existsSync()) {
              try {
                patchFile.deleteSync();
              } catch (_) {}
            }
          }
        }

        // --- PATH B: FULL SPLIT APK DOWNLOAD (or automatic fallback) ---
        if (!apkReady) {
          if (info.downloadUrl.isEmpty) {
            controller.add(const UpdateProgress(
              stage: UpdateStage.error,
              progress: 0,
              message: 'No download URL available for this update.',
            ));
            await controller.close();
            return;
          }

          final abiSuffix =
              info.selectedAbi.isNotEmpty ? ' (${info.selectedAbi})' : '';
          await _downloadFile(
            url: info.downloadUrl,
            destination: outputApkFile,
            expectedBytes: info.fullApkSizeBytes,
            onProgress: (fraction, received, total) {
              final pct = (fraction * 100).clamp(0, 100).toInt();
              final sizeLabel = total > 0
                  ? '${UpdateInfo.formatBytes(received)} / ${UpdateInfo.formatBytes(total)}'
                  : UpdateInfo.formatBytes(received);
              controller.add(UpdateProgress(
                stage: UpdateStage.downloadingFull,
                progress: fraction * 0.90,
                message: 'Downloading APK$abiSuffix: $pct% ($sizeLabel)',
              ));
            },
          );

          if (info.fullApkSha256 != null && info.fullApkSha256!.isNotEmpty) {
            controller.add(const UpdateProgress(
              stage: UpdateStage.verifying,
              progress: 0.95,
              message: 'Verifying APK checksum...',
            ));
            final actualSha = await computeFileSha256(outputApkFile.path);
            if (actualSha != null &&
                actualSha.toLowerCase() != info.fullApkSha256!.toLowerCase()) {
              if (outputApkFile.existsSync()) outputApkFile.deleteSync();
              controller.add(const UpdateProgress(
                stage: UpdateStage.error,
                progress: 0,
                message: 'Downloaded APK checksum verification failed.',
              ));
              await controller.close();
              return;
            }
          }
        }

        // --- LAUNCH ANDROID INSTALLER ---
        controller.add(const UpdateProgress(
          stage: UpdateStage.installing,
          progress: 1.0,
          message: 'Launching package installer...',
        ));

        final installResult = await installLocalApk(outputApkFile.path);
        if (installResult == 'PERMISSION_REQUIRED') {
          controller.add(const UpdateProgress(
            stage: UpdateStage.permissionRequired,
            progress: 1.0,
            message:
                'Enable "Allow from this source" in Android Settings, then tap Update again.',
          ));
        }
      } catch (e) {
        controller.add(UpdateProgress(
          stage: UpdateStage.error,
          progress: 0,
          message: 'Update failed: $e',
        ));
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  Future<void> _downloadFile({
    required String url,
    required File destination,
    int? expectedBytes,
    required void Function(double fraction, int received, int total) onProgress,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'LedgerApp');
      final response =
          await request.close().timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} while downloading $url');
      }

      final totalBytes = response.contentLength > 0
          ? response.contentLength
          : (expectedBytes ?? 0);
      int receivedBytes = 0;

      final sink = destination.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          final fraction = totalBytes > 0
              ? (receivedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0;
          onProgress(fraction, receivedBytes, totalBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
    } finally {
      client.close();
    }
  }

  /// Semantic-version-first comparison so `--split-per-abi` ABI-offset
  /// Android versionCodes never break update detection.
  static bool isNewerVersion({
    required String remoteVersion,
    required int remoteBuild,
    required String localVersion,
    required int localBuild,
  }) {
    final semverCmp = compareSemanticVersions(remoteVersion, localVersion);
    if (semverCmp != 0) {
      return semverCmp > 0;
    }
    if (remoteBuild > 0 && localBuild > 0) {
      return remoteBuild > localBuild;
    }
    return false;
  }

  static int compareSemanticVersions(String v1, String v2) {
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
      final cacheBuster = url.contains('?') ? '&' : '?';
      final fetchUri = Uri.parse(
        '$url${cacheBuster}_t=${DateTime.now().millisecondsSinceEpoch}',
      );
      final request = await client.getUrl(fetchUri);
      request.headers.set('User-Agent', 'LedgerApp');
      request.headers.set('Cache-Control', 'no-cache, no-store, must-revalidate');
      request.headers.set('Pragma', 'no-cache');
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
