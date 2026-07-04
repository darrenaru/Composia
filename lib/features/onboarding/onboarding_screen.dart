import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/custom_button.dart';
import '../../services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  final StorageService storageService;

  const OnboardingScreen({super.key, required this.storageService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      icon: Icons.document_scanner_rounded,
      title: AppStrings.onboarding1Title,
      description: AppStrings.onboarding1Desc,
      color: AppColors.primary,
    ),
    _OnboardingPage(
      icon: Icons.psychology_rounded,
      title: AppStrings.onboarding2Title,
      description: AppStrings.onboarding2Desc,
      color: AppColors.accent,
    ),
    _OnboardingPage(
      icon: Icons.verified_rounded,
      title: AppStrings.onboarding3Title,
      description: AppStrings.onboarding3Desc,
      color: AppColors.safeGreen,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await widget.storageService.markOnboardingDone();
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Lewati',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
            ).animate().fadeIn(duration: 400.ms),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) => _OnboardingPageWidget(
                  page: _pages[i],
                  isActive: i == _currentPage,
                ),
              ),
            ),
            _buildIndicators(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GradientButton(
                label: _currentPage == _pages.length - 1
                    ? 'Mulai Sekarang'
                    : 'Lanjutkan',
                onPressed: _onNext,
                icon: _currentPage == _pages.length - 1
                    ? Icons.rocket_launch_rounded
                    : Icons.arrow_forward_rounded,
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: i == _currentPage ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i == _currentPage
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;
  final bool isActive;

  const _OnboardingPageWidget({
    required this.page,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  page.color.withOpacity(0.15),
                  page.color.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(48),
              border: Border.all(
                color: page.color.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Icon(page.icon, size: 72, color: page.color),
          )
              .animate(target: isActive ? 1 : 0)
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.8, 0.8), duration: 400.ms),
          const SizedBox(height: 40),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ).animate(target: isActive ? 1 : 0).fadeIn(delay: 150.ms),
          const SizedBox(height: 16),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ).animate(target: isActive ? 1 : 0).fadeIn(delay: 250.ms),
        ],
      ),
    );
  }
}
