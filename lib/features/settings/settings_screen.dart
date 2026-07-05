import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/tab_header.dart';
import '../../services/storage_service.dart';
import '../../services/update_service.dart';

class SettingsScreen extends StatefulWidget {
  final StorageService storageService;

  const SettingsScreen({super.key, required this.storageService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _appVersion = info.version);
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);
    final update = await UpdateService().checkForUpdate(_appVersion);
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (update == null) {
      _showSnack('Sudah versi terbaru.');
      return;
    }

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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? AppColors.dangerRed : AppColors.safeGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TabHeader(title: AppStrings.settingsTitle),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAllergyProfileCard(context)
                        .animate()
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 24),
                    _buildAboutSection().animate().fadeIn(duration: 400.ms),
                    const SizedBox(height: 24),
                    _buildDangerZone()
                        .animate()
                        .fadeIn(delay: 250.ms, duration: 400.ms),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAllergyProfileCard(BuildContext context) {
    return _SectionCard(
      title: 'Profil Alergi',
      icon: Icons.health_and_safety_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Atur bahan yang bikin kamu sensitif supaya hasil analisis menyorotnya otomatis.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/allergy-profile'),
            icon: const Icon(Icons.tune_rounded),
            label: const Text('Atur Profil Alergi'),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return _SectionCard(
      title: 'Tentang Composia',
      icon: Icons.info_rounded,
      child: Column(
        children: [
          _buildInfoRow(
            Icons.biotech_rounded,
            'Versi Aplikasi',
            _appVersion,
          ),
          const Divider(height: 24, color: AppColors.divider),
          _buildInfoRow(
            Icons.language_rounded,
            'Bahasa',
            'Bahasa Indonesia',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isCheckingUpdate ? null : _checkForUpdate,
            icon: _isCheckingUpdate
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.system_update_rounded),
            label: Text(_isCheckingUpdate ? 'Memeriksa...' : 'Cek Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildDangerZone() {
    return _SectionCard(
      title: 'Zona Berbahaya',
      icon: Icons.warning_rounded,
      iconColor: AppColors.dangerRed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tindakan berikut tidak dapat dibatalkan.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _confirmClearHistory,
            icon: const Icon(Icons.delete_sweep_rounded,
                color: AppColors.dangerRed),
            label: const Text(
              'Hapus Semua Riwayat',
              style: TextStyle(color: AppColors.dangerRed),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.dangerRed),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text(
            'Semua riwayat scan akan dihapus secara permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus',
                style: TextStyle(color: AppColors.dangerRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.storageService.clearHistory();
      _showSnack('Semua riwayat berhasil dihapus');
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Icon(icon,
                    size: 20, color: iconColor ?? AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }
}
