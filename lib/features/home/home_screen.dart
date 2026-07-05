import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/category_style.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/scan_result_card.dart';
import '../../core/widgets/tab_header.dart';
import '../../core/widgets/update_dialog.dart';
import '../../models/analysis_result.dart';
import '../../services/storage_service.dart';
import '../../services/update_service.dart';
import 'widgets/tip_card.dart';

class HomeScreen extends StatefulWidget {
  final StorageService storageService;

  const HomeScreen({super.key, required this.storageService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AnalysisResult> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    widget.storageService.historyChanged.addListener(_loadHistory);
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final info = await PackageInfo.fromPlatform();
    final update = await UpdateService().checkForUpdate(info.version);
    if (update == null || !mounted) return;
    showUpdateDialog(context, update);
  }

  @override
  void dispose() {
    widget.storageService.historyChanged.removeListener(_loadHistory);
    super.dispose();
  }

  void _loadHistory() {
    setState(() {
      _history = widget.storageService.getHistory();
    });
  }

  void _pushScan(BuildContext context) {
    context.push('/recognize').then((_) => _loadHistory());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadHistory();
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi!';
    if (hour < 15) return 'Selamat Siang!';
    if (hour < 18) return 'Selamat Sore!';
    return 'Selamat Malam!';
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
              TabHeader(eyebrow: _greeting, title: AppStrings.homeSubGreeting),
              _buildHistory(context),
              const SizedBox(height: 24),
              _buildTips(),
              const SizedBox(height: 24),
              _buildCategories(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories() {
    const categories = [
      ProductCategory.medicine,
      ProductCategory.cosmetics,
      ProductCategory.skincare,
      ProductCategory.babyProduct,
      ProductCategory.supplement,
      ProductCategory.personalCare,
      ProductCategory.foodBeverage,
      ProductCategory.household,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Kategori Produk',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final cat = categories[i];
              return AppChip(
                label: cat.label,
                icon: cat.icon,
                color: cat.color,
                onTap: () => _pushScan(context),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 60));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const TipCard(
        tip: 'Tips: Pastikan label bahan terlihat jelas dan fokus saat mengambil foto untuk hasil analisis yang lebih akurat.',
        icon: Icons.lightbulb_rounded,
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                AppStrings.recentScans,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_history.isNotEmpty)
                TextButton(
                  onPressed: () => context.go('/history'),
                  child: const Text('Lihat Semua'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_history.isEmpty)
          _buildEmptyHistory()
        else
          ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.take(3).length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final item = _history[i];
              return ScanResultCard(
                result: item,
                onTap: () => context.push('/result/${item.id}'),
              ).animate().fadeIn(delay: Duration(milliseconds: i * 100));
            },
          ),
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: AppCard(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.image_search_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              AppStrings.noHistory,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              AppStrings.noHistoryDesc,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
