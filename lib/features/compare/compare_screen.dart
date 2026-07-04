import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../models/analysis_result.dart';
import '../../models/ingredient.dart';
import '../../services/storage_service.dart';
import '../result/widgets/safety_badge.dart';

double _severityWeight(SafetyLevel level) {
  switch (level) {
    case SafetyLevel.safe:
      return 0;
    case SafetyLevel.caution:
      return 1;
    case SafetyLevel.warning:
      return 2;
    case SafetyLevel.danger:
      return 3;
    case SafetyLevel.unknown:
      return 1;
  }
}

double _averageSeverity(AnalysisResult result) {
  if (result.ingredients.isEmpty) return 0;
  final total = result.ingredients
      .map((i) => _severityWeight(i.safetyLevel))
      .reduce((a, b) => a + b);
  return total / result.ingredients.length;
}

class CompareScreen extends StatelessWidget {
  final String idA;
  final String idB;
  final StorageService storageService;

  const CompareScreen({
    super.key,
    required this.idA,
    required this.idB,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    final resultA = storageService.getResultById(idA);
    final resultB = storageService.getResultById(idB);

    if (resultA == null || resultB == null) {
      return Scaffold(
        appBar: const CustomAppBar(title: 'Bandingkan Produk'),
        body: const Center(child: Text('Salah satu hasil tidak ditemukan')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Bandingkan Produk'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: _buildHeaderColumn(resultA)),
              const SizedBox(width: 12),
              Expanded(child: _buildHeaderColumn(resultB)),
            ],
          ),
          const SizedBox(height: 16),
          _buildVerdict(resultA, resultB),
          const SizedBox(height: 24),
          const Text(
            'Perbandingan Bahan',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildIngredientRows(resultA, resultB),
        ],
      ),
    );
  }

  Widget _buildHeaderColumn(AnalysisResult result) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.productName ?? 'Produk Tanpa Nama',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          SafetyBadge(level: result.overallSafetyLevel, compact: true),
        ],
      ),
    );
  }

  Widget _buildVerdict(AnalysisResult a, AnalysisResult b) {
    final scoreA = _averageSeverity(a);
    final scoreB = _averageSeverity(b);
    final diff = (scoreA - scoreB).abs();

    String text;
    if (diff <= 0.3) {
      text = 'Kira-kira setara dari sisi keamanan bahan.';
    } else if (scoreA < scoreB) {
      text = '${a.productName ?? "Produk A"} kira-kira lebih aman.';
    } else {
      text = '${b.productName ?? "Produk B"} kira-kira lebih aman.';
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: AppColors.primary.withOpacity(0.06),
      borderColor: Colors.transparent,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildIngredientRows(AnalysisResult a, AnalysisResult b) {
    final mapA = <String, Ingredient>{
      for (final i in a.ingredients) i.name.toLowerCase().trim(): i,
    };
    final mapB = <String, Ingredient>{
      for (final i in b.ingredients) i.name.toLowerCase().trim(): i,
    };
    final keys = {...mapA.keys, ...mapB.keys}.toList()..sort();

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: keys.asMap().entries.map((entry) {
          final key = entry.value;
          final ingA = mapA[key];
          final ingB = mapB[key];
          final displayName = (ingA ?? ingB)!.name;
          final isLast = entry.key == keys.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        displayName,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textPrimary),
                      ),
                    ),
                    Expanded(child: _buildPresenceBadge(ingA)),
                    Expanded(child: _buildPresenceBadge(ingB)),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: AppColors.divider),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPresenceBadge(Ingredient? ingredient) {
    if (ingredient == null) {
      return const Center(
        child: Text('-', style: TextStyle(color: AppColors.textHint)),
      );
    }
    return Center(
      child:
          SafetyBadge(level: ingredient.safetyLevel, compact: true, showIcon: false),
    );
  }
}
