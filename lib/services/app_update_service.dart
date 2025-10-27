import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.minimumVersion,
    required this.downloadUrl,
    this.notes,
  });

  final String latestVersion;
  final String minimumVersion;
  final String downloadUrl;
  final String? notes;

  bool needsUpdate(String currentVersion) =>
      _compareVersions(currentVersion, latestVersion) < 0;

  bool requiresUpgrade(String currentVersion) =>
      _compareVersions(currentVersion, minimumVersion) < 0;

  static AppUpdateInfo? fromResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      final android = _selectPlatformBlock(data);
      if (android == null) return null;
      final latest =
          _readString(android, ['latestVersion', 'latest', 'version']);
      final minimum =
          _readString(android, ['minimumVersion', 'minVersion', 'minimum']);
      final download =
          _readString(android, ['downloadUrl', 'apkUrl', 'url', 'link']);
      final notes = _readString(android, ['notes', 'changelog', 'message']);
      if (latest == null || minimum == null || download == null) {
        return null;
      }
      return AppUpdateInfo(
        latestVersion: latest,
        minimumVersion: minimum,
        downloadUrl: download,
        notes: notes,
      );
    }
    return null;
  }

  static Map<String, dynamic>? _selectPlatformBlock(Map<String, dynamic> data) {
    if (data['android'] is Map<String, dynamic>) {
      return (data['android'] as Map).cast<String, dynamic>();
    }
    return data;
  }
}

class AppUpdateService {
  AppUpdateService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 6),
    ),
  );

  static AppUpdateInfo? _cachedInfo;
  static bool _promptShown = false;
  static bool _loading = false;

  static Future<void> ensureLatest(BuildContext context) async {
    if (kIsWeb) return;
    if (androidUpdateManifestUrl.isEmpty) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    if (!context.mounted) return;
    if (_loading) return;

    _loading = true;
    try {
      final info = await _loadInfo();
      if (info == null) {
        return;
      }

      final package = await PackageInfo.fromPlatform();
      final version = package.version;
      final requiresUpgrade = info.requiresUpgrade(version);
      final hasUpdate = info.needsUpdate(version);

      if (!requiresUpgrade && (!hasUpdate || _promptShown)) {
        return;
      }

      if (!context.mounted) {
        return;
      }

      _promptShown = true;
      await _showDialog(context, info, version,
          requiresUpgrade: requiresUpgrade);
    } finally {
      _loading = false;
    }
  }

  static Future<AppUpdateInfo?> _loadInfo() async {
    if (_cachedInfo != null) {
      return _cachedInfo;
    }

    try {
      final response = await _dio.get<dynamic>(
        androidUpdateManifestUrl,
        options: Options(responseType: ResponseType.json),
      );
      final info = AppUpdateInfo.fromResponse(response.data);
      if (info != null) {
        _cachedInfo = info;
      }
      return info;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _showDialog(
    BuildContext parent,
    AppUpdateInfo info,
    String currentVersion, {
    required bool requiresUpgrade,
  }) async {
    final messenger = ScaffoldMessenger.maybeOf(parent);
    await showDialog<void>(
      context: parent,
      barrierDismissible: !requiresUpgrade,
      builder: (dialogContext) {
        return PopScope(
          canPop: !requiresUpgrade,
          child: AlertDialog(
            title:
                Text(requiresUpgrade ? 'Update required' : 'Update available'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  requiresUpgrade
                      ? 'This version ($currentVersion) is no longer supported. Please install the latest release to continue.'
                      : 'Version ${info.latestVersion} is available. You are using $currentVersion.',
                ),
                if (info.notes != null && info.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(info.notes!),
                ],
              ],
            ),
            actions: [
              if (!requiresUpgrade)
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Later'),
                ),
              FilledButton(
                onPressed: () async {
                  final uri = Uri.tryParse(info.downloadUrl.trim());
                  if (uri == null) {
                    messenger?.showSnackBar(
                      const SnackBar(
                          content: Text('Download link is invalid.')),
                    );
                    return;
                  }
                  final launched = await launchUrl(
                    uri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched) {
                    messenger?.showSnackBar(
                      const SnackBar(
                          content: Text('Could not open download link.')),
                    );
                    return;
                  }
                  if (!requiresUpgrade && dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Download update'),
              ),
            ],
          ),
        );
      },
    );
  }
}

int _compareVersions(String a, String b) {
  final aParts = _parseVersion(a);
  final bParts = _parseVersion(b);
  final maxLength =
      aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < maxLength; i++) {
    final aValue = i < aParts.length ? aParts[i] : 0;
    final bValue = i < bParts.length ? bParts[i] : 0;
    if (aValue != bValue) {
      return aValue.compareTo(bValue);
    }
  }
  return 0;
}

List<int> _parseVersion(String value) {
  return value
      .split('.')
      .map(
        (part) => int.tryParse(RegExp(r'^(\d+)').stringMatch(part) ?? '0') ?? 0,
      )
      .toList();
}

String? _readString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}
