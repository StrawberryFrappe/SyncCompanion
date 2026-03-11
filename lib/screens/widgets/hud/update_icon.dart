import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/update_service.dart';

class UpdateIcon extends StatefulWidget {
  const UpdateIcon({super.key});

  @override
  State<UpdateIcon> createState() => _UpdateIconState();
}

class _UpdateIconState extends State<UpdateIcon> {
  @override
  void initState() {
    super.initState();
    UpdateService().checkForUpdates();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: UpdateService().updateUrlNotifier,
      builder: (context, updateUrl, child) {
        if (updateUrl == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () async {
            if (updateUrl.toLowerCase().endsWith('.apk')) {
              await UpdateService().downloadAndInstallUpdate(updateUrl);
            } else {
              // Fallback to old behavior if not an APK
              final uri = Uri.parse(updateUrl);
              try {
                if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                  debugPrint('Could not launch $uri');
                }
              } catch (e) {
                debugPrint('Could not launch $uri: $e');
              }
            }
          },
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              shape: BoxShape.circle,
              border: Border.all(width: 2, color: Colors.black),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            ),
            child: ValueListenableBuilder<bool>(
              valueListenable: UpdateService().isDownloadingNotifier,
              builder: (context, isDownloading, child) {
                if (isDownloading) {
                  return ValueListenableBuilder<double>(
                    valueListenable: UpdateService().downloadProgressNotifier,
                    builder: (context, progress, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress > 0 ? progress : null,
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                }
                
                return const Icon(
                  Icons.system_update,
                  color: Colors.white,
                  size: 24,
                );
              },
            ),
          ),
        );
      },
    );
  }
}
