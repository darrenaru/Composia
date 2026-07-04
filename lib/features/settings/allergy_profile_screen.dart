import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_chip.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../services/storage_service.dart';

// ponytail: matching berbasis substring nama, bukan basis data kimia —
// term 'ci ' untuk Pewarna (CI) adalah heuristik kasar, bisa false-positive
// pada nama bahan lain yang kebetulan mengandung "ci ".
const _commonAllergens = <(String label, String term)>[
  ('Fragrance / Parfum', 'fragrance'),
  ('Paraben', 'paraben'),
  ('Sulfate (SLS/SLES)', 'sulfate'),
  ('Alcohol Denat', 'alcohol denat'),
  ('Silicone', 'silicone'),
  ('Nikel', 'nickel'),
  ('Pewarna (CI)', 'ci '),
  ('Formaldehyde Releaser', 'formaldehyde'),
];

class AllergyProfileScreen extends StatefulWidget {
  final StorageService storageService;

  const AllergyProfileScreen({super.key, required this.storageService});

  @override
  State<AllergyProfileScreen> createState() => _AllergyProfileScreenState();
}

class _AllergyProfileScreenState extends State<AllergyProfileScreen> {
  late List<String> _profile;
  final _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _profile = widget.storageService.getAllergyProfile();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _persist() {
    widget.storageService.setAllergyProfile(_profile);
  }

  void _toggleCommon(String term) {
    setState(() {
      if (_profile.contains(term)) {
        _profile.remove(term);
      } else {
        _profile.add(term);
      }
    });
    _persist();
  }

  void _addCustom() {
    final term = _customController.text.trim().toLowerCase();
    if (term.isEmpty || _profile.contains(term)) return;
    setState(() => _profile.add(term));
    _customController.clear();
    _persist();
  }

  void _removeCustom(String term) {
    setState(() => _profile.remove(term));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final commonTerms = _commonAllergens.map((e) => e.$2).toSet();
    final customTerms =
        _profile.where((t) => !commonTerms.contains(t)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CustomAppBar(title: 'Profil Alergi'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Tandai bahan yang bikin kamu sensitif. Hasil analisis akan menyorot bahan yang cocok.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _commonAllergens.map((entry) {
              final (label, term) = entry;
              final selected = _profile.contains(term);
              return AppChip(
                label: label,
                icon: Icons.warning_amber_rounded,
                color: AppColors.warningOrange,
                selected: selected,
                onTap: () => _toggleCommon(term),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bahan Custom',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customController,
                  decoration: const InputDecoration(
                    hintText: 'Nama bahan lain...',
                  ),
                  onSubmitted: (_) => _addCustom(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addCustom,
                icon: const Icon(Icons.add_circle_rounded,
                    color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (customTerms.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: customTerms.map((term) {
                return AppChip(
                  label: term,
                  icon: Icons.warning_amber_rounded,
                  color: AppColors.warningOrange,
                  onDeleted: () => _removeCustom(term),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
