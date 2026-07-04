import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/analysis_result.dart';
import '../../services/storage_service.dart';
import '../result/widgets/safety_badge.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storageService;

  const HistoryScreen({super.key, required this.storageService});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AnalysisResult> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() => _history = widget.storageService.getHistory());
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Hapus Semua Riwayat?'),
        content: const Text(
          'Semua riwayat scan akan dihapus secara permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(color: AppColors.dangerRed),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.storageService.clearHistory();
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(AppStrings.historyTitle),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          if (_history.isNotEmpty)
            TextButton(
              onPressed: _confirmClearAll,
              child: const Text(
                AppStrings.clearAll,
                style: TextStyle(color: AppColors.dangerRed),
              ),
            ),
        ],
      ),
      body: _history.isEmpty ? _buildEmpty() : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.history_rounded,
              size: 44,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            AppStrings.noHistory,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            AppStrings.noHistoryDesc,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final grouped = _groupByDate(_history);
    final keys = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: keys.length,
      itemBuilder: (context, groupIndex) {
        final date = keys[groupIndex];
        final items = grouped[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
              child: Text(
                date,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            ...items.asMap().entries.map((entry) {
              final i = entry.key;
              final result = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HistoryCard(
                  result: result,
                  onTap: () => context
                      .push('/result/${result.id}')
                      .then((_) => _loadHistory()),
                  onDelete: () async {
                    await widget.storageService
                        .removeFromHistory(result.id);
                    _loadHistory();
                  },
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: i * 60)),
              );
            }),
          ],
        );
      },
    );
  }

  Map<String, List<AnalysisResult>> _groupByDate(List<AnalysisResult> list) {
    final map = <String, List<AnalysisResult>>{};
    for (final item in list) {
      final now = DateTime.now();
      final date = item.analyzedAt;
      String key;
      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        key = 'HARI INI';
      } else if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day - 1) {
        key = 'KEMARIN';
      } else {
        key = DateFormat('d MMMM yyyy', 'id').format(date);
      }
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }
}

class _HistoryCard extends StatelessWidget {
  final AnalysisResult result;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const _HistoryCard({
    required this.result,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(result.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.dangerRed,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.productName ?? 'Produk Tanpa Nama',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.ingredients.length} bahan • ${DateFormat('HH:mm').format(result.analyzedAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SafetyBadge(level: result.overallSafetyLevel, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: _color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(_icon, color: _color, size: 24),
    );
  }

  IconData get _icon {
    switch (result.category) {
      case ProductCategory.medicine:
        return Icons.medication_rounded;
      case ProductCategory.cosmetics:
        return Icons.face_retouching_natural_rounded;
      case ProductCategory.skincare:
        return Icons.spa_rounded;
      case ProductCategory.babyProduct:
        return Icons.child_care_rounded;
      case ProductCategory.supplement:
        return Icons.health_and_safety_rounded;
      case ProductCategory.personalCare:
        return Icons.self_improvement_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  Color get _color {
    switch (result.category) {
      case ProductCategory.medicine:
        return const Color(0xFF6C5CE7);
      case ProductCategory.cosmetics:
        return const Color(0xFFFF7675);
      case ProductCategory.skincare:
        return const Color(0xFF00B894);
      case ProductCategory.babyProduct:
        return const Color(0xFFFDCB6E);
      case ProductCategory.supplement:
        return const Color(0xFF74B9FF);
      case ProductCategory.personalCare:
        return const Color(0xFFE17055);
      default:
        return AppColors.primary;
    }
  }
}
