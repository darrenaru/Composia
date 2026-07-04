import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/category_style.dart';
import '../../../models/ingredient.dart';
import 'safety_badge.dart';

class IngredientCard extends StatefulWidget {
  final Ingredient ingredient;
  final VoidCallback? onTap;
  final bool matchesAllergyProfile;

  const IngredientCard({
    super.key,
    required this.ingredient,
    this.onTap,
    this.matchesAllergyProfile = false,
  });

  @override
  State<IngredientCard> createState() => _IngredientCardState();
}

class _IngredientCardState extends State<IngredientCard> {
  bool _expanded = false;

  Color get _levelColor => widget.ingredient.safetyLevel.color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.matchesAllergyProfile
                ? AppColors.dangerRed
                : (_expanded ? _levelColor.withOpacity(0.3) : AppColors.border),
            width: widget.matchesAllergyProfile ? 2 : (_expanded ? 1.5 : 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildExpandedContent(),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: _levelColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.ingredient.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (widget.matchesAllergyProfile ||
                    widget.ingredient.isCommonAllergen) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (widget.matchesAllergyProfile)
                        _buildBadge('Cocok Profil Alergimu',
                            AppColors.dangerRed, AppColors.dangerRedLight),
                      if (widget.ingredient.isCommonAllergen)
                        _buildBadge('Alergen', AppColors.warningOrange,
                            AppColors.warningOrangeLight),
                    ],
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  widget.ingredient.function,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              SafetyBadge(level: widget.ingredient.safetyLevel, compact: true),
              const SizedBox(height: 6),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: AppColors.textHint,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    final ing = widget.ingredient;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          if (ing.inci != null && ing.inci!.isNotEmpty) ...[
            _buildInfoRow('Nama INCI', ing.inci!, Icons.science_rounded),
            const SizedBox(height: 8),
          ],
          _buildDescription(ing.description),
          if (ing.safetyReason.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              'Alasan Rating',
              ing.safetyReason,
              Icons.shield_rounded,
              color: _levelColor,
            ),
          ],
          if (ing.benefits.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBulletList(
              'Manfaat',
              ing.benefits,
              Icons.thumb_up_rounded,
              AppColors.safeGreen,
            ),
          ],
          if (ing.concerns.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildBulletList(
              'Potensi Risiko',
              ing.concerns,
              Icons.warning_amber_rounded,
              AppColors.warningOrange,
            ),
          ],
          if (ing.ewgScore != null) ...[
            const SizedBox(height: 10),
            _buildInfoRow(
              'Skor EWG',
              ing.ewgScore!,
              Icons.analytics_rounded,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescription(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.6,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon,
      {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color ?? AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, height: 1.5),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(color: color ?? AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBulletList(
      String title, List<String> items, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
