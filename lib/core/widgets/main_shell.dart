import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimens.dart';
import '../constants/app_strings.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  static const _items = [
    (Icons.home_rounded, AppStrings.navHomeLabel),
    (Icons.search_rounded, AppStrings.navSearchLabel),
    (Icons.history_rounded, AppStrings.navHistoryLabel),
    (Icons.settings_rounded, AppStrings.navSettingsLabel),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(child: Center(child: _navItemFor(0))),
              Expanded(child: Center(child: _navItemFor(1))),
              Expanded(
                child: Center(
                  child: _ScanCenterButton(
                      onTap: () => context.push('/recognize')),
                ),
              ),
              Expanded(child: Center(child: _navItemFor(2))),
              Expanded(child: Center(child: _navItemFor(3))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItemFor(int i) {
    final (icon, label) = _items[i];
    return _NavItem(
      icon: icon,
      label: label,
      selected: navigationShell.currentIndex == i,
      onTap: () => navigationShell.goBranch(
        i,
        initialLocation: i == navigationShell.currentIndex,
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textHint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanCenterButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ScanCenterButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.document_scanner_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
