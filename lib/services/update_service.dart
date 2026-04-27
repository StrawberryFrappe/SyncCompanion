import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _lastNightlyState = false;

  Future<void> checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g., "1.0.0"

      final prefs = await SharedPreferences.getInstance();
      final isNightlyEnabled = prefs.getBool('nightly_updates_enabled') ?? false;
      final isUnstableEnabled = prefs.getBool('unstable_updates_enabled') ?? false;

      // If preferences changed since last check, allow re-checking
      if (_hasChecked && (isNightlyEnabled != _lastNightlyState)) {
        _hasChecked = false;
        updateUrlNotifier.value = null;
      }
      if (_hasChecked) return;
      _hasChecked = true;
      _lastNightlyState = isNightlyEnabled;

      final url = isNightlyEnabled
          ? 'https://api.github.com/repos/StrawberryFrappe/Therapets/releases'
          : 'https://api.github.com/repos/StrawberryFrappe/Therapets/releases/latest';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final rawData = jsonDecode(response.body);
        final Map<String, dynamic> data;

        if (isNightlyEnabled && rawData is List && rawData.isNotEmpty) {
          // GitHub's /releases endpoint sorts stable releases before
          // prereleases. Find the latest entry that matches user preference.
          final Map<String, dynamic>? targetEntry = (rawData as List).firstWhere(
            (r) {
              final tagName = (r['tag_name'] as String).toLowerCase();
              if (isUnstableEnabled && tagName.contains('unstable')) return true;
              if (tagName.contains('nightly')) return true;
              return false;
            },
            orElse: () => null,
          );
          if (targetEntry == null) return;
          data = targetEntry;
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
          
          if (_isNewerVersion(currentVersion, releaseVersion, isNightlyEnabled: isNightlyEnabled)) {
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

  bool _isNewerVersion(String current, String release, {bool isNightlyEnabled = false}) {
    // Regex matches v1.2.3 or 1.2.3-nightly.4 or 1.2.3-unstable.5
    final regex = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:-(nightly|unstable)\.(\d+))?');
    
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
    
    // When the user opted into nightly updates, any nightly release is always
    // considered newer than the current stable build — dev is always ahead of
    // main. This check runs before the base-version comparison so that the
    // version skew between branches (e.g. 1.0.1-nightly vs 1.0.2) can't
    // cause a false negative.
    final releaseIsNightly = releaseMatch.group(4) != null;
    final currentIsStable = currentMatch.group(4) == null;
    if (isNightlyEnabled && releaseIsNightly && currentIsStable) {
      return true;
    }

    // Compare major, minor, patch
    for (int i = 1; i <= 3; i++) {
      int c = int.parse(currentMatch.group(i) ?? '0');
      int r = int.parse(releaseMatch.group(i) ?? '0');
      if (r > c) return true;
      if (r < c) return false;
    }
    
    // Same base version. Check build numbers.
    String? currentType = currentMatch.group(4); // nightly or unstable
    String? currentBuildStr = currentMatch.group(5);
    
    String? releaseType = releaseMatch.group(4);
    String? releaseBuildStr = releaseMatch.group(5);
    
    // If one is stable and the other is pre-release, the stable is newer
    if (currentType != null && releaseType == null) {
      return true; // Release is stable, current is pre-release → upgrade
    }
    if (currentType == null && releaseType != null) {
      // Current is stable, release is pre-release → only upgrade if user opted in
      return isNightlyEnabled;
    }
    
    // Both are pre-releases
    if (currentBuildStr != null && releaseBuildStr != null) {
      // If same type, compare build numbers
      if (currentType == releaseType) {
        int cBuild = int.parse(currentBuildStr);
        int rBuild = int.parse(releaseBuildStr);
        return rBuild > cBuild;
      }
      // If different types, unstable is always considered "newer" than nightly
      // because it's more experimental/ahead in terms of features.
      return releaseType == 'unstable';
    }
    
    return false; // Identical or unknown
  }
}
