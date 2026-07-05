import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/update_service.dart';

void showUpdateDialog(BuildContext context, UpdateInfo update) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Update Tersedia'),
      content: Text(
        'Versi ${update.latestVersion} sudah tersedia. Unduh dan pasang untuk mendapatkan perbaikan terbaru.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            launchUrl(Uri.parse(update.downloadUrl),
                mode: LaunchMode.externalApplication);
          },
          child: const Text('Update Sekarang'),
        ),
      ],
    ),
  );
}
