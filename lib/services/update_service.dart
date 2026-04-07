import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // URL to the .apk file or the release page as fallback
  final ValueNotifier<String?> updateUrlNotifier = ValueNotifier(null);
  
  // Progress tracker (0.0 to 1.0)
  final ValueNotifier<double> downloadProgressNotifier = ValueNotifier(0.0);
  
  // State tracker for UI changes
  final ValueNotifier<bool> isDownloadingNotifier = ValueNotifier(false);

  bool _hasChecked = false;

  Future<void> checkForUpdates() async {
    if (_hasChecked) return;
    _hasChecked = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g., "1.0.0"

      final prefs = await SharedPreferences.getInstance();
      final isNightlyEnabled = prefs.getBool('nightly_updates_enabled') ?? false;

      final url = isNightlyEnabled
          ? 'https://api.github.com/repos/StrawberryFrappe/SyncCompanion/releases'
          : 'https://api.github.com/repos/StrawberryFrappe/SyncCompanion/releases/latest';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final rawData = jsonDecode(response.body);
        final Map<String, dynamic> data;

        if (isNightlyEnabled && rawData is List && rawData.isNotEmpty) {
          data = rawData.first;
        } else if (!isNightlyEnabled && rawData is Map<String, dynamic>) {
          data = rawData;
        } else {
          return;
        }

        final String tagName = data['tag_name'] ?? '';
        
        // Find the APK download URL from the assets array
        String downloadUrl = '';
        if (data['assets'] != null) {
          for (var asset in data['assets']) {
            final name = asset['name']?.toString().toLowerCase() ?? '';
            if (name.endsWith('.apk')) {
              downloadUrl = asset['browser_download_url'] ?? '';
              break;
            }
          }
        }
        
        // Fallback to the release page if no APK asset is found
        if (downloadUrl.isEmpty) {
          downloadUrl = data['html_url'] ?? '';
        }

        if (tagName.isNotEmpty && downloadUrl.isNotEmpty) {
          final releaseVersion = tagName.replaceAll('v', '');
          
          if (_isNewerVersion(currentVersion, releaseVersion)) {
            updateUrlNotifier.value = downloadUrl;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      _hasChecked = false; // Allow retrying if it failed
    }
  }

  Future<void> downloadAndInstallUpdate(String url) async {
    if (isDownloadingNotifier.value) return;

    // If it's not an APK file, it's the fallback html_url, we can't download it
    if (!url.toLowerCase().endsWith('.apk')) {
      debugPrint('Update URL is not an APK. Cannot download and install.');
      return;
    }

    try {
      isDownloadingNotifier.value = true;
      downloadProgressNotifier.value = 0.0;

      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/update.apk';

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadProgressNotifier.value = received / total;
          }
        },
      );

      // Trigger the installation
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        debugPrint('Failed to open APK: ${result.message}');
      }
    } catch (e) {
      debugPrint('Error downloading update: $e');
    } finally {
      isDownloadingNotifier.value = false;
      downloadProgressNotifier.value = 0.0;
    }
  }

  bool _isNewerVersion(String current, String release) {
    final regex = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:-nightly\.(\d+))?');
    
    final currentMatch = regex.firstMatch(current);
    final releaseMatch = regex.firstMatch(release);
    
    if (currentMatch == null || releaseMatch == null) {
      // Fallback to simple split logic
      if (!release.contains('.')) return false;
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
    
    // Compare major, minor, patch
    for (int i = 1; i <= 3; i++) {
      int c = int.parse(currentMatch.group(i) ?? '0');
      int r = int.parse(releaseMatch.group(i) ?? '0');
      if (r > c) return true;
      if (r < c) return false;
    }
    
    // Same base version. Check nightly numbers.
    String? currentNightlyStr = currentMatch.group(4);
    String? releaseNightlyStr = releaseMatch.group(4);
    
    // If one is stable and the other is nightly, the stable is newer
    if (currentNightlyStr != null && releaseNightlyStr == null) {
      return true; // Release is stable, current is nightly
    }
    if (currentNightlyStr == null && releaseNightlyStr != null) {
      return false; // Current is stable, release is nightly
    }
    
    // Both are nightly
    if (currentNightlyStr != null && releaseNightlyStr != null) {
      int cNightly = int.parse(currentNightlyStr);
      int rNightly = int.parse(releaseNightlyStr);
      return rNightly > cNightly; // True if release nightly number > current
    }
    
    return false; // Identical
  }
}
