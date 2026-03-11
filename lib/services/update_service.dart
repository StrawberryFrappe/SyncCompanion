import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  final ValueNotifier<String?> updateUrlNotifier = ValueNotifier(null);
  bool _hasChecked = false;

  Future<void> checkForUpdates() async {
    if (_hasChecked) return;
    _hasChecked = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g., "1.0.0"

      final response = await http.get(Uri.parse('https://api.github.com/repos/StrawberryFrappe/SyncCompanion/releases/latest'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String tagName = data['tag_name'] ?? '';
        final String htmlUrl = data['html_url'] ?? '';

        if (tagName.isNotEmpty && htmlUrl.isNotEmpty) {
          final releaseVersion = tagName.replaceAll('v', '');
          
          if (_isNewerVersion(currentVersion, releaseVersion)) {
            updateUrlNotifier.value = htmlUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      _hasChecked = false; // Allow retrying if it failed
    }
  }

  bool _isNewerVersion(String current, String release) {
    List<int> currentParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    List<int> releaseParts = release.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < releaseParts.length; i++) {
        int c = i < currentParts.length ? currentParts[i] : 0;
        int r = releaseParts[i];
        if (r > c) return true;
        if (r < c) return false;
    }
    return false;
  }
}
