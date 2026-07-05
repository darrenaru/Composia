import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../services/update_service.dart';

void showUpdateDialog(BuildContext context, UpdateInfo update) {
  showDialog(
    context: context,
    builder: (context) => _UpdateDialog(update: update),
  );
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo update;
  const _UpdateDialog({required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      final path = await UpdateService().downloadApk(
        widget.update.downloadUrl,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
      await OpenFilex.open(path);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _progress = null;
        _error = 'Gagal mengunduh update. Periksa koneksi internet kamu.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDownloading = _progress != null;

    return AlertDialog(
      title: const Text('Update Tersedia'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: isDownloading
            ? [
                LinearProgressIndicator(
                    value: _progress == 0 ? null : _progress),
                const SizedBox(height: 12),
                Text('${(_progress! * 100).toStringAsFixed(0)}%'),
              ]
            : [
                Text(
                  _error ??
                      'Versi ${widget.update.latestVersion} sudah tersedia. '
                          'Unduh dan pasang untuk mendapatkan perbaikan terbaru.',
                ),
              ],
      ),
      actions: isDownloading
          ? []
          : [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Nanti'),
              ),
              FilledButton(
                onPressed: _startDownload,
                child: const Text('Update Sekarang'),
              ),
            ],
    );
  }
}
