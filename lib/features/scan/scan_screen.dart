import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/widgets/custom_button.dart';
import '../../core/widgets/loading_overlay.dart';
import 'bloc/scan_bloc.dart';
import 'bloc/scan_event.dart';
import 'bloc/scan_state.dart';
import 'widgets/image_preview_widget.dart';
import 'widgets/source_option_card.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<ScanBloc, ScanState>(
      listener: (context, state) {
        if (state is ScanSuccess) {
          context.pushReplacement('/result/${state.result.id}');
        } else if (state is ScanError) {
          _showError(context, state);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(AppStrings.scanTitle),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: BlocBuilder<ScanBloc, ScanState>(
          builder: (context, state) {
            return Stack(
              children: [
                _buildContent(context, state),
                if (state is ScanAnalyzing)
                  const LoadingOverlay(
                    message: AppStrings.analyzing,
                    subtitle: AppStrings.analyzingDesc,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ScanState state) {
    if (state is ScanInitial || state is ScanImageLoading) {
      return _buildInitialView(context, state is ScanImageLoading);
    }
    if (state is ScanImageReady || state is ScanAnalyzing) {
      final image = state is ScanImageReady
          ? state.image
          : (state as ScanAnalyzing).image;
      return _buildImageReadyView(context, image);
    }
    return _buildInitialView(context, false);
  }

  Widget _buildInitialView(BuildContext context, bool loading) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildInstructionCard(),
          const SizedBox(height: 28),
          const Text(
            'Pilih Sumber Foto',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SourceOptionCard(
            icon: Icons.camera_alt_rounded,
            title: AppStrings.takePicture,
            subtitle: 'Ambil foto langsung menggunakan kamera',
            color: AppColors.primary,
            isLoading: loading,
            onTap: loading
                ? null
                : () => context.read<ScanBloc>().add(
                      const ScanImageFromCamera(),
                    ),
          ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.05, end: 0),
          const SizedBox(height: 12),
          SourceOptionCard(
            icon: Icons.photo_library_rounded,
            title: AppStrings.chooseGallery,
            subtitle: 'Pilih foto dari galeri perangkat kamu',
            color: AppColors.accent,
            onTap: loading
                ? null
                : () => context.read<ScanBloc>().add(
                      const ScanImageFromGallery(),
                    ),
          ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideX(begin: -0.05, end: 0),
        ],
      ),
    );
  }

  Widget _buildInstructionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.08),
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.tips_and_updates_rounded,
            color: AppColors.primary,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            AppStrings.scanInstruction,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildImageReadyView(BuildContext context, File image) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                ImagePreviewWidget(
                  image: image,
                  onRetake: () => context.read<ScanBloc>().add(
                        const ScanImageCleared(),
                      ),
                ).animate().fadeIn(duration: 350.ms),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.safeGreenLight,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.safeGreen.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.safeGreen, size: 20),
                      SizedBox(width: 10),
                      Text(
                        AppStrings.imageSelected,
                        style: TextStyle(
                          color: AppColors.safeGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: GradientButton(
            label: AppStrings.analyzeButton,
            icon: Icons.biotech_rounded,
            onPressed: () => context.read<ScanBloc>().add(
                  const ScanAnalyzeRequested(),
                ),
          ),
        ),
      ],
    );
  }

  void _showError(BuildContext context, ScanError state) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(state.message),
        backgroundColor:
            state.isApiKeyError ? AppColors.warningOrange : AppColors.dangerRed,
        action: state.isApiKeyError
            ? SnackBarAction(
                label: 'Pengaturan',
                textColor: Colors.white,
                onPressed: () => context.push('/settings'),
              )
            : null,
        duration: const Duration(seconds: 5),
      ),
    );
  }
}
