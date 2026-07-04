import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class MainShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_rounded),
            label: AppStrings.navHomeLabel,
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: AppStrings.navHistoryLabel,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: AppStrings.navSettingsLabel,
          ),
        ],
      ),
    );
  }
}
