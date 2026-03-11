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
            final uri = Uri.parse(updateUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            ),
            child: const Icon(
              Icons.system_update,
              color: Colors.white,
              size: 24,
            ),
          ),
        );
      },
    );
  }
}
