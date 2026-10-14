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
  final String? apkDownloadUrl;
  final String? ipaDownloadUrl;
  final bool hasUpdate;

  ReleaseInfo({
    required this.tagName,
    required this.cleanVersion,
    required this.name,
    required this.body,
    required this.htmlUrl,
    this.apkDownloadUrl,
    this.ipaDownloadUrl,
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

  /// Compare two semver strings (e.g. "1.0.3" vs "1.0.2")
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

  /// Checks GitHub Releases for the latest version
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

          String? apkUrl;
          String? ipaUrl;
          final assets = data['assets'];
          if (assets is List) {
            for (final a in assets) {
              if (a is Map) {
                final aname = a['name']?.toString() ?? '';
                final durl = a['browser_download_url']?.toString();
                if (aname.endsWith('.apk') && durl != null) {
                  apkUrl = durl;
                } else if (aname.endsWith('.ipa') && durl != null) {
                  ipaUrl = durl;
                }
              }
            }
          }

          final hasUpdate = compareVersions(cleanTag, AppConfig.appVersion) > 0;

          return UpdateCheckResult(
            success: true,
            release: ReleaseInfo(
              tagName: tagName,
              cleanVersion: cleanTag,
              name: name,
              body: body,
              htmlUrl: htmlUrl,
              apkDownloadUrl: apkUrl,
              ipaDownloadUrl: ipaUrl,
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

  /// Launch external browser/downloader for release or asset
  static Future<bool> openReleaseUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(uri);
    } catch (e) {
      debugPrint('[UpdateService] Launch URL error: $e');
      return false;
    }
  }
}
