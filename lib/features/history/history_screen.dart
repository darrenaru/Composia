import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/scan_result_card.dart';
import '../../models/analysis_result.dart';
import '../../services/storage_service.dart';

class HistoryScreen extends StatefulWidget {
  final StorageService storageService;

  const HistoryScreen({super.key, required this.storageService});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AnalysisResult> _history = [];
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() => _history = widget.storageService.getHistory());
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else if (_selectedIds.length < 2) {
        _selectedIds.add(id);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Maksimal 2 produk untuk dibandingkan')),
        );
      }
    });
  }

  void _goToCompare() {
    final ids = _selectedIds.toList();
    context.push('/compare/${ids[0]}/${ids[1]}').then((_) {
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
    });
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
      appBar: CustomAppBar(
        title: AppStrings.historyTitle,
        actions: [
          if (_history.length >= 2)
            IconButton(
              onPressed: _toggleSelectionMode,
              icon: Icon(_selectionMode
                  ? Icons.close_rounded
                  : Icons.compare_arrows_rounded),
              tooltip: _selectionMode ? 'Batal' : 'Bandingkan',
            ),
          if (!_selectionMode && _history.isNotEmpty)
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
      bottomNavigationBar: _selectionMode && _selectedIds.length == 2
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PrimaryButton(
                  label: 'Bandingkan (2)',
                  onPressed: _goToCompare,
                ),
              ),
            )
          : null,
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
                child: ScanResultCard(
                  result: result,
                  selectionMode: _selectionMode,
                  selected: _selectedIds.contains(result.id),
                  dismissible: true,
                  showRelativeDate: false,
                  onTap: _selectionMode
                      ? () => _toggleSelected(result.id)
                      : () => context
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

