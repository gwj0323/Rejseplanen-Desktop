import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';

class ReleaseInfo {
  final String tagName;
  final String cleanVersion;
  final String name;
  final String body;
  final String htmlUrl;
  final bool hasUpdate;

  ReleaseInfo({
    required this.tagName,
    required this.cleanVersion,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.hasUpdate,
  });
}

class UpdateCheckResult {
  final bool success;
  final ReleaseInfo? release;
  final String? error;

  UpdateCheckResult({required this.success, this.release, this.error});
}

class UpdateService {
  static const String repoOwner = 'gwj0323';
  static const String repoName = 'spor-app';

  /// Compare two semver strings (e.g. "1.2.1" vs "1.2.0")
  /// Returns > 0 if v1 > v2, < 0 if v1 < v2, 0 if equal.
  static int compareVersions(String v1, String v2) {
    List<int> parse(String v) {
      final clean = v.replaceAll(RegExp(r'^[vV]'), '').split('+').first.trim();
      return clean.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    }

    final p1 = parse(v1);
    final p2 = parse(v2);
    final len = p1.length > p2.length ? p1.length : p2.length;

    for (int i = 0; i < len; i++) {
      final n1 = i < p1.length ? p1[i] : 0;
      final n2 = i < p2.length ? p2[i] : 0;
      if (n1 != n2) return n1.compareTo(n2);
    }
    return 0;
  }

  /// Checks for the latest version metadata
  static Future<UpdateCheckResult> checkUpdate() async {
    try {
      final url = Uri.parse('https://api.github.com/repos/$repoOwner/$repoName/releases/latest');
      final resp = await http.get(url, headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'Spor-Mobile-App',
      }).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) {
          final tagName = data['tag_name']?.toString() ?? '';
          final cleanTag = tagName.replaceAll(RegExp(r'^[vV]'), '');
          final name = data['name']?.toString() ?? tagName;
          final body = data['body']?.toString() ?? '';
          final htmlUrl = data['html_url']?.toString() ?? 'https://github.com/$repoOwner/$repoName/releases';

          final hasUpdate = compareVersions(cleanTag, AppConfig.appVersion) > 0;

          return UpdateCheckResult(
            success: true,
            release: ReleaseInfo(
              tagName: tagName,
              cleanVersion: cleanTag,
              name: name,
              body: body,
              htmlUrl: htmlUrl,
              hasUpdate: hasUpdate,
            ),
          );
        }
      } else if (resp.statusCode == 404) {
        return UpdateCheckResult(success: true, release: null);
      }
      return UpdateCheckResult(
        success: false,
        error: 'HTTP ${resp.statusCode}',
      );
    } catch (e) {
      debugPrint('[UpdateService] Check update error: $e');
      return UpdateCheckResult(success: false, error: e.toString());
    }
  }

  /// Opens Google Play Store on Android to comply with Google Play Device and Network Abuse policy.
  /// On other platforms, opens the project release page.
  static Future<bool> openStoreOrReleaseUrl({String? fallbackUrl}) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        return await openGooglePlayStore();
      } else {
        final targetUrl = fallbackUrl ?? 'https://github.com/$repoOwner/$repoName/releases';
        final uri = Uri.parse(targetUrl);
        if (await canLaunchUrl(uri)) {
          return await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        return await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('[UpdateService] Launch URL error: $e');
      return false;
    }
  }

  /// Direct to Google Play Store app first, fallback to browser link
  static Future<bool> openGooglePlayStore() async {
    try {
      final marketUri = Uri.parse(AppConfig.googlePlayMarketUri);
      if (await canLaunchUrl(marketUri)) {
        return await launchUrl(marketUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    try {
      final webUri = Uri.parse(AppConfig.googlePlayUrl);
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[UpdateService] Launch Google Play URL error: $e');
      return false;
    }
  }
}
