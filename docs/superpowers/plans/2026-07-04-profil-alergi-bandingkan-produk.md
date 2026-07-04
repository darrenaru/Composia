# Profil Alergi & Bandingkan Produk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambah dua fitur ke Composia: profil alergi personal (highlight bahan yang cocok sensitivitas user) dan bandingkan 2 produk dari riwayat.

**Architecture:** Keduanya murni client-side di atas data yang sudah ada (`AnalysisResult`/`Ingredient` tersimpan di `SharedPreferences` lewat `StorageService`). Tidak ada perubahan ke `GeminiService` atau prompt. Matching bahan pakai substring lowercase — sederhana, jalan retroaktif ke riwayat lama.

**Tech Stack:** Flutter/Dart, `flutter_bloc` (tidak dipakai di dua fitur ini — keduanya `StatefulWidget`/`StatelessWidget` biasa), `go_router`, `shared_preferences`, `flutter_test`.

## Global Constraints

- Tidak ada penambahan pemanggilan Gemini API — kedua fitur murni post-processing lokal.
- Matching bahan (allergy & compare) case-insensitive substring by name/inci — bukan pemetaan kimia/sinonim (batasan yang disadari, dari spec).
- Maksimal 2 produk untuk dibandingkan sekaligus.
- Profil alergi auto-save tiap perubahan (toggle chip / tambah / hapus custom), tanpa tombol simpan terpisah.
- Swipe-to-delete (`Dismissible`) di History dimatikan selama mode pilih (`_selectionMode`) aktif.
- Package name project: `composia` (dipakai untuk import di test, mis. `package:composia/services/storage_service.dart`).

---

### Task 1: Storage layer untuk profil alergi

**Files:**
- Modify: `lib/services/storage_service.dart`
- Test: `test/storage_service_allergy_test.dart`

**Interfaces:**
- Produces: `List<String> StorageService.getAllergyProfile()`, `Future<void> StorageService.setAllergyProfile(List<String> terms)` — dipakai Task 3 (UI) dan Task 4 (Result screen).

- [ ] **Step 1: Write the failing test**

```dart
// test/storage_service_allergy_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:composia/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getAllergyProfile returns empty list by default', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    expect(storage.getAllergyProfile(), isEmpty);
  });

  test('setAllergyProfile persists lowercase, trimmed, deduped terms', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();
    await storage.setAllergyProfile([' Fragrance ', 'Paraben', 'fragrance']);
    expect(storage.getAllergyProfile(), ['fragrance', 'paraben']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/storage_service_allergy_test.dart`
Expected: FAIL — `getAllergyProfile`/`setAllergyProfile` undefined on `StorageService`.

- [ ] **Step 3: Write minimal implementation**

In `lib/services/storage_service.dart`, add a new key constant next to the existing ones and two methods anywhere inside the `StorageService` class (e.g. right after `getApiKey()`):

```dart
  static const String _allergyProfileKey = 'composia_allergy_profile';

  // Allergy Profile
  List<String> getAllergyProfile() =>
      _prefs.getStringList(_allergyProfileKey) ?? [];

  Future<void> setAllergyProfile(List<String> terms) {
    final cleaned = terms
        .map((t) => t.trim().toLowerCase())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    return _prefs.setStringList(_allergyProfileKey, cleaned);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/storage_service_allergy_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/services/storage_service.dart test/storage_service_allergy_test.dart
git commit -m "feat: add allergy profile storage to StorageService"
```

---

### Task 2: Allergy matching utility

**Files:**
- Create: `lib/core/utils/allergy_matcher.dart`
- Test: `test/allergy_matcher_test.dart`

**Interfaces:**
- Consumes: `Ingredient` (`lib/models/ingredient.dart`) — fields `name` (`String`), `inci` (`String?`).
- Produces: `bool ingredientMatchesAllergyProfile(Ingredient ingredient, List<String> profile)` — dipakai Task 4 (Result screen).

- [ ] **Step 1: Write the failing test**

```dart
// test/allergy_matcher_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:composia/core/utils/allergy_matcher.dart';
import 'package:composia/models/ingredient.dart';

Ingredient _ingredient({required String name, String? inci}) {
  return Ingredient(
    name: name,
    inci: inci,
    function: 'test',
    description: 'test',
    safetyLevel: SafetyLevel.safe,
    safetyReason: 'test',
  );
}

void main() {
  test('matches when profile term is substring of ingredient name', () {
    final ing = _ingredient(name: 'Parfum (Fragrance)');
    expect(ingredientMatchesAllergyProfile(ing, ['fragrance']), isTrue);
  });

  test('matches when profile term is substring of inci name', () {
    final ing = _ingredient(name: 'Pengawet', inci: 'Methylparaben');
    expect(ingredientMatchesAllergyProfile(ing, ['paraben']), isTrue);
  });

  test('does not match when profile is empty', () {
    final ing = _ingredient(name: 'Aqua');
    expect(ingredientMatchesAllergyProfile(ing, []), isFalse);
  });

  test('does not match unrelated ingredient', () {
    final ing = _ingredient(name: 'Aqua', inci: 'Water');
    expect(ingredientMatchesAllergyProfile(ing, ['paraben']), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/allergy_matcher_test.dart`
Expected: FAIL — `package:composia/core/utils/allergy_matcher.dart` does not exist.

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/utils/allergy_matcher.dart
import '../../models/ingredient.dart';

bool ingredientMatchesAllergyProfile(
  Ingredient ingredient,
  List<String> profile,
) {
  if (profile.isEmpty) return false;
  final name = ingredient.name.toLowerCase();
  final inci = ingredient.inci?.toLowerCase();
  for (final term in profile) {
    if (term.isEmpty) continue;
    if (name.contains(term)) return true;
    if (inci != null && inci.contains(term)) return true;
  }
  return false;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/allergy_matcher_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/core/utils/allergy_matcher.dart test/allergy_matcher_test.dart
git commit -m "feat: add allergy matcher utility"
```

---

### Task 3: Allergy Profile screen + Settings entry + router

**Files:**
- Create: `lib/features/settings/allergy_profile_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/router/app_router.dart`

**Interfaces:**
- Consumes: `StorageService.getAllergyProfile()`, `StorageService.setAllergyProfile()` (Task 1).
- Produces: route `/allergy-profile` — dipakai dari `settings_screen.dart`.

- [ ] **Step 1: Create the screen**

```dart
// lib/features/settings/allergy_profile_screen.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Profil Alergi'),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
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
              return FilterChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => _toggleCommon(term),
                selectedColor: AppColors.primary.withOpacity(0.15),
                checkmarkColor: AppColors.primary,
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
                return Chip(
                  label: Text(term),
                  onDeleted: () => _removeCustom(term),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Add entry card in Settings screen**

In `lib/features/settings/settings_screen.dart`, add the import:

```dart
import 'allergy_profile_screen.dart';
```

Add a new card method (place it right before `_buildAboutSection`):

```dart
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
```

In the same file's `build()` method, insert the card before `_buildAboutSection()`:

```dart
          children: [
            _buildAllergyProfileCard(context)
                .animate()
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            _buildAboutSection().animate().fadeIn(duration: 400.ms),
```

- [ ] **Step 3: Wire the route**

In `lib/router/app_router.dart`, add the import:

```dart
import '../features/settings/allergy_profile_screen.dart';
```

Add the route (anywhere in the `routes` list, e.g. right after `/settings`):

```dart
      GoRoute(
        path: '/allergy-profile',
        builder: (context, state) =>
            AllergyProfileScreen(storageService: storageService),
      ),
```

- [ ] **Step 4: Verify it builds**

Run: `flutter analyze`
Expected: no new errors (pre-existing `withOpacity` deprecation infos are fine and unrelated).

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/allergy_profile_screen.dart lib/features/settings/settings_screen.dart lib/router/app_router.dart
git commit -m "feat: add allergy profile screen and route"
```

---

### Task 4: Highlight matched ingredients in Result screen

**Files:**
- Modify: `lib/features/result/widgets/ingredient_card.dart`
- Modify: `lib/features/result/result_screen.dart`

**Interfaces:**
- Consumes: `ingredientMatchesAllergyProfile` (Task 2), `StorageService.getAllergyProfile()` (Task 1).

- [ ] **Step 1: Add `matchesAllergyProfile` param to IngredientCard**

In `lib/features/result/widgets/ingredient_card.dart`, update the widget fields and constructor:

```dart
class IngredientCard extends StatefulWidget {
  final Ingredient ingredient;
  final int index;
  final VoidCallback? onTap;
  final bool matchesAllergyProfile;

  const IngredientCard({
    super.key,
    required this.ingredient,
    required this.index,
    this.onTap,
    this.matchesAllergyProfile = false,
  });
```

Update the card's border decoration inside `build()` (replace the existing `border:` line in the `AnimatedContainer`'s `BoxDecoration`):

```dart
          border: Border.all(
            color: widget.matchesAllergyProfile
                ? AppColors.dangerRed
                : (_expanded ? _levelColor.withOpacity(0.3) : AppColors.border),
            width: widget.matchesAllergyProfile ? 2 : (_expanded ? 1.5 : 1),
          ),
```

Replace the inline "Alergen" chip logic inside `_buildHeader()` — change this existing block:

```dart
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.ingredient.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (widget.ingredient.isCommonAllergen)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warningOrangeLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Alergen',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.warningOrange,
                          ),
                        ),
                      ),
                  ],
                ),
```

to:

```dart
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
```

Add the new helper method anywhere in `_IngredientCardState` (e.g. right after `_buildHeader`):

```dart
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
```

- [ ] **Step 2: Compute and pass allergy matches in ResultScreen**

In `lib/features/result/result_screen.dart`, add the import:

```dart
import '../../core/utils/allergy_matcher.dart';
```

Add a field and update `_loadResult()`:

```dart
  AnalysisResult? _result;
  SafetyLevel? _filterLevel;
  List<String> _allergyProfile = [];
```

```dart
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
```

In `_buildOverviewTab()`, insert the banner right after `OverallSafetyIndicator`:

```dart
          OverallSafetyIndicator(level: result.overallSafetyLevel)
              .animate()
              .fadeIn(duration: 400.ms),
          const SizedBox(height: 16),
          if (_matchedAllergyIngredients.isNotEmpty) ...[
            _buildAllergyBanner(),
            const SizedBox(height: 16),
          ],
```

Add the banner method (e.g. right after `_buildOverviewTab`):

```dart
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
```

In `_buildIngredientsTab()`, update the `itemBuilder` to pass the flag:

```dart
                  itemBuilder: (context, i) {
                    final ingredient = _filteredIngredients[i];
                    return IngredientCard(
                      ingredient: ingredient,
                      index: i,
                      matchesAllergyProfile: ingredientMatchesAllergyProfile(
                          ingredient, _allergyProfile),
                    );
                  },
```

- [ ] **Step 3: Verify it builds**

Run: `flutter analyze`
Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/result/widgets/ingredient_card.dart lib/features/result/result_screen.dart
git commit -m "feat: highlight ingredients matching user's allergy profile"
```

---

### Task 5: History screen selection mode for comparison

**Files:**
- Modify: `lib/features/history/history_screen.dart`

**Interfaces:**
- Produces: navigation to `/compare/:idA/:idB` (consumed by Task 6).

- [ ] **Step 1: Add selection-mode state and toggle**

In `_HistoryScreenState`, add fields:

```dart
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};
```

Add methods (e.g. right after `_loadHistory`):

```dart
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
```

- [ ] **Step 2: Update AppBar actions and add bottom compare bar**

Replace the `actions:` list in the `AppBar` (inside `build()`):

```dart
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
```

Add `bottomNavigationBar` to the `Scaffold` (sibling of `body:`):

```dart
      bottomNavigationBar: _selectionMode && _selectedIds.length == 2
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: _goToCompare,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Bandingkan (2)',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            )
          : null,
```

- [ ] **Step 3: Pass selection state into `_HistoryCard` and disable swipe during selection**

Update the `_HistoryCard` instantiation inside `_buildList()`:

```dart
                child: _HistoryCard(
                  result: result,
                  selectionMode: _selectionMode,
                  selected: _selectedIds.contains(result.id),
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
```

Update the `_HistoryCard` class itself — replace its full body with:

```dart
class _HistoryCard extends StatelessWidget {
  final AnalysisResult result;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final bool selectionMode;
  final bool selected;

  const _HistoryCard({
    required this.result,
    this.onTap,
    this.onDelete,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.textHint,
              ),
              const SizedBox(width: 12),
            ],
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
    );

    if (selectionMode) return card;

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
      child: card,
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
```

- [ ] **Step 4: Verify it builds**

Run: `flutter analyze`
Expected: no new errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/history/history_screen.dart
git commit -m "feat: add product selection mode to History screen for comparison"
```

---

### Task 6: Compare screen

**Files:**
- Create: `lib/features/compare/compare_screen.dart`
- Modify: `lib/router/app_router.dart`

**Interfaces:**
- Consumes: `StorageService.getResultById(String id)` (existing), route params `idA`/`idB` from Task 5's navigation.

- [ ] **Step 1: Create the screen**

```dart
// lib/features/compare/compare_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
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
        appBar: AppBar(title: const Text('Bandingkan Produk')),
        body: const Center(child: Text('Salah satu hasil tidak ditemukan')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Bandingkan Produk'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
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
          ..._buildIngredientRows(resultA, resultB),
        ],
      ),
    );
  }

  Widget _buildHeaderColumn(AnalysisResult result) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
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

  List<Widget> _buildIngredientRows(AnalysisResult a, AnalysisResult b) {
    final mapA = <String, Ingredient>{
      for (final i in a.ingredients) i.name.toLowerCase().trim(): i,
    };
    final mapB = <String, Ingredient>{
      for (final i in b.ingredients) i.name.toLowerCase().trim(): i,
    };
    final keys = {...mapA.keys, ...mapB.keys}.toList()..sort();

    return keys.map((key) {
      final ingA = mapA[key];
      final ingB = mapB[key];
      final displayName = (ingA ?? ingB)!.name;

      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  displayName,
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                ),
              ),
              Expanded(child: _buildPresenceBadge(ingA)),
              Expanded(child: _buildPresenceBadge(ingB)),
            ],
          ),
        ),
      );
    }).toList();
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
```

- [ ] **Step 2: Wire the route**

In `lib/router/app_router.dart`, add the import:

```dart
import '../features/compare/compare_screen.dart';
```

Add the route (e.g. right after `/allergy-profile`):

```dart
      GoRoute(
        path: '/compare/:idA/:idB',
        builder: (context, state) => CompareScreen(
          idA: state.pathParameters['idA']!,
          idB: state.pathParameters['idB']!,
          storageService: storageService,
        ),
      ),
```

- [ ] **Step 3: Verify it builds**

Run: `flutter analyze`
Expected: no new errors.

- [ ] **Step 4: Commit**

```bash
git add lib/features/compare/compare_screen.dart lib/router/app_router.dart
git commit -m "feat: add product comparison screen"
```

---

### Task 7: Manual verification pass

**Files:** none (verification only)

- [ ] **Step 1: Run full test suite**

Run: `flutter test`
Expected: all tests pass (6 tests from Tasks 1–2, plus any pre-existing).

- [ ] **Step 2: Build and install debug APK on connected device**

Run: `flutter run -d <device-id>` (or reuse the device used earlier this session, `72bb307d`)

- [ ] **Step 3: Verify allergy profile flow**

- Buka Pengaturan → Profil Alergi, centang "Paraben", kembali.
- Scan ulang produk yang mengandung paraben di daftar bahan (atau buka hasil lama yang ada bahan mengandung "paraben" di nama/inci).
- Expected: tab Ringkasan menampilkan banner merah, tab Daftar Bahan menampilkan kartu bahan itu dengan border merah + chip "Cocok Profil Alergimu".

- [ ] **Step 4: Verify compare flow**

- Buka Riwayat, tap icon Bandingkan, pilih 2 produk, tap "Bandingkan (2)".
- Expected: layar Bandingkan Produk terbuka, menampilkan 2 header, satu baris verdict, dan daftar bahan gabungan dengan badge keamanan per produk.

- [ ] **Step 5: Final commit (if any manual fixes were needed)**

```bash
git add -A
git commit -m "fix: address issues found during manual verification"
```

(Skip this step if no changes were needed.)
