import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../core/widgets/loading_overlay.dart';
import '../scan/widgets/source_option_card.dart';
import 'bloc/recognize_bloc.dart';
import 'bloc/recognize_event.dart';
import 'bloc/recognize_state.dart';

class RecognizeScreen extends StatelessWidget {
  const RecognizeScreen({super.key});

  Future<void> _pickPhoto(BuildContext context, ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked != null && context.mounted) {
      context.read<RecognizeBloc>().add(PhotoTaken(File(picked.path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecognizeBloc, RecognizeState>(
      listener: (context, state) {
        if (state is RecognizeSuccess) {
          context.pushReplacement('/result/${state.result.id}');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: const CustomAppBar(title: 'Kenali Produk'),
        body: BlocBuilder<RecognizeBloc, RecognizeState>(
          builder: (context, state) {
            return Stack(
              children: [
                _buildContent(context, state),
                if (state is RecognizeAnalyzingPhoto ||
                    state is RecognizeSearchingComposition ||
                    state is RecognizeAnalyzing)
                  LoadingOverlay(
                    message: 'Menganalisis foto...',
                    subtitle: _loadingSubtitle(state),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _loadingSubtitle(RecognizeState state) {
    if (state is RecognizeSearchingComposition) {
      return 'Mencari komposisi ${state.productName}...';
    }
    if (state is RecognizeAnalyzing) return 'Menyusun hasil analisis...';
    return 'Membaca foto produk...';
  }

  Widget _buildContent(BuildContext context, RecognizeState state) {
    if (state is RecognizeNotFound) {
      return _buildMessage(
        context,
        icon: Icons.search_off_rounded,
        iconColor: AppColors.textHint,
        message:
            'Produk tidak dapat dikenali otomatis. Coba foto ulang dengan pencahayaan yang lebih jelas.',
      );
    }
    if (state is RecognizeError) {
      return _buildMessage(
        context,
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.dangerRed,
        message: state.message,
      );
    }
    return _buildInitialView(context);
  }

  Widget _buildInitialView(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            backgroundColor: AppColors.primary.withOpacity(0.06),
            borderColor: Colors.transparent,
            child: const Text(
              'Foto label komposisi ATAU foto kemasan produk saja — sistem akan otomatis mengenali mana yang kamu foto dan mencari data komposisinya.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ..._buildSourceOptions(context),
        ],
      ),
    );
  }

  Widget _buildMessage(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(icon, size: 48, color: iconColor),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 28),
          ..._buildSourceOptions(context),
        ],
      ),
    );
  }

  List<Widget> _buildSourceOptions(BuildContext context) {
    return [
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
        title: 'Ambil Foto',
        subtitle: 'Ambil foto langsung menggunakan kamera',
        color: AppColors.primary,
        onTap: () => _pickPhoto(context, ImageSource.camera),
      ),
      const SizedBox(height: 12),
      SourceOptionCard(
        icon: Icons.photo_library_rounded,
        title: 'Pilih dari Galeri',
        subtitle: 'Pilih foto dari galeri perangkat kamu',
        color: AppColors.accent,
        onTap: () => _pickPhoto(context, ImageSource.gallery),
      ),
    ];
  }
}
