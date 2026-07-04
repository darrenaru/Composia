import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/allergy_matcher.dart';
import '../../models/analysis_result.dart';
import '../../models/ingredient.dart';
import '../../services/storage_service.dart';
import 'widgets/ingredient_card.dart';
import 'widgets/product_summary_card.dart';
import 'widgets/safety_badge.dart';

class ResultScreen extends StatefulWidget {
  final String resultId;
  final StorageService storageService;

  const ResultScreen({
    super.key,
    required this.resultId,
    required this.storageService,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AnalysisResult? _result;
  SafetyLevel? _filterLevel;
  List<String> _allergyProfile = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadResult();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadResult() {
    final result = widget.storageService.getResultById(widget.resultId);
    setState(() {
      _result = result;
      _allergyProfile = widget.storageService.getAllergyProfile();
    });
  }

  List<Ingredient> get _matchedAllergyIngredients {
    if (_result == null || _allergyProfile.isEmpty) return [];
    return _result!.ingredients
        .where((i) => ingredientMatchesAllergyProfile(i, _allergyProfile))
        .toList();
  }

  List<Ingredient> get _filteredIngredients {
    if (_result == null) return [];
    if (_filterLevel == null) return _result!.ingredients;
    return _result!.ingredients
        .where((i) => i.safetyLevel == _filterLevel)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_result == null) {
      return Scaffold(
        appBar: AppBar(title: const Text(AppStrings.resultTitle)),
        body: const Center(child: Text('Hasil tidak ditemukan')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(AppStrings.resultTitle),
        actions: [
          IconButton(
            onPressed: _showOptions,
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildIngredientsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textHint,
        indicatorColor: AppColors.primary,
        indicatorWeight: 3,
        tabs: const [
          Tab(text: 'Ringkasan'),
          Tab(text: 'Daftar Bahan'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final result = _result!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverallSafetyIndicator(level: result.overallSafetyLevel)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          if (_matchedAllergyIngredients.isNotEmpty) ...[
            _buildAllergyBanner(),
            const SizedBox(height: 16),
          ],
          if (result.overallSafetyNote.isNotEmpty) ...[
            _buildSection(
              child: Text(
                result.overallSafetyNote,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          _buildSection(
            child: ProductSummaryCard(result: result),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildAllergyBanner() {
    final names = _matchedAllergyIngredients.map((i) => i.name).join(', ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerRedLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dangerRed.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.dangerRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_matchedAllergyIngredients.length} bahan cocok dengan profil alergimu: $names',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsTab() {
    final result = _result!;
    if (result.ingredients.isEmpty) {
      return Column(
        children: [
          _buildFilterBar(),
          Expanded(child: _buildEmptyIngredients()),
        ],
      );
    }

    return CustomScrollView(
      // Bangun kartu sedikit di luar viewport lebih dulu supaya tidak ada
      // jeda kosong saat scroll cepat (dulu ditutupi animasi fade-in per item,
      // yang justru bikin pop-in terlihat tiap kartu baru di-build).
      // ignore: deprecated_member_use
      cacheExtent: 600,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _FilterBarDelegate(_buildFilterBar()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          sliver: SliverList.separated(
            itemCount: _filteredIngredients.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final ingredient = _filteredIngredients[i];
              return IngredientCard(
                key: ValueKey(ingredient.name),
                ingredient: ingredient,
                matchesAllergyProfile: ingredientMatchesAllergyProfile(
                    ingredient, _allergyProfile),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final levels = [
      (null, 'Semua', AppColors.textSecondary),
      (SafetyLevel.safe, 'Aman', AppColors.safeGreen),
      (SafetyLevel.caution, 'Hati-hati', AppColors.cautionYellow),
      (SafetyLevel.warning, 'Peringatan', AppColors.warningOrange),
      (SafetyLevel.danger, 'Berbahaya', AppColors.dangerRed),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: levels.map((level) {
            final isSelected = _filterLevel == level.$1;
            return GestureDetector(
              onTap: () => setState(() => _filterLevel = level.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? level.$3.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? level.$3
                        : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  level.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? level.$3 : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyIngredients() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppColors.textHint),
          SizedBox(height: 12),
          Text(
            'Tidak ada bahan yang ditemukan',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_outline_rounded, color: AppColors.dangerRed),
            title: const Text('Hapus dari Riwayat'),
            textColor: AppColors.dangerRed,
            onTap: () async {
              Navigator.pop(ctx);
              await widget.storageService
                  .removeFromHistory(widget.resultId);
              if (mounted) context.go('/home');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _FilterBarDelegate(this.child);

  static const double _height = 54;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(height: _height, child: child);
  }

  @override
  bool shouldRebuild(covariant _FilterBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
