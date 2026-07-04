import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import 'bloc/recognize_bloc.dart';
import 'bloc/recognize_event.dart';
import 'bloc/recognize_state.dart';

class RecognizeScreen extends StatefulWidget {
  const RecognizeScreen({super.key});

  @override
  State<RecognizeScreen> createState() => _RecognizeScreenState();
}

class _RecognizeScreenState extends State<RecognizeScreen> {
  bool _barcodeHandled = false;

  void _onBarcodeDetect(BarcodeCapture capture) {
    if (_barcodeHandled) return;
    final code =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null) return;
    _barcodeHandled = true;
    context.read<RecognizeBloc>().add(BarcodeDetected(code));
  }

  Future<void> _pickPackagingPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (picked != null && mounted) {
      context
          .read<RecognizeBloc>()
          .add(PackagingPhotoCaptured(File(picked.path)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Kenali Produk'),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
      ),
      body: BlocConsumer<RecognizeBloc, RecognizeState>(
        listener: (context, state) {
          if (state is RecognizeSuccess) {
            context.pushReplacement('/result/${state.result.id}');
          }
        },
        builder: (context, state) {
          if (state is RecognizeNotFound) {
            return _buildMessage(
              icon: Icons.search_off_rounded,
              iconColor: AppColors.textHint,
              message: 'Produk tidak dapat dikenali otomatis.',
            );
          }
          if (state is RecognizeError) {
            return _buildMessage(
              icon: Icons.error_outline_rounded,
              iconColor: AppColors.dangerRed,
              message: state.message,
            );
          }
          if (state is RecognizeLookingUp ||
              state is RecognizeIdentifying ||
              state is RecognizeSearchingComposition ||
              state is RecognizeAnalyzing) {
            return _buildLoading(state);
          }
          return _buildScanner();
        },
      ),
    );
  }

  Widget _buildScanner() {
    return Stack(
      children: [
        MobileScanner(onDetect: _onBarcodeDetect),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Arahkan kamera ke barcode kemasan produk',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage({
    required IconData icon,
    required Color iconColor,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: iconColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 20),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading(RecognizeState state) {
    var label = 'Memproses...';
    if (state is RecognizeLookingUp) label = 'Mencari data produk...';
    if (state is RecognizeIdentifying) label = 'Mengenali kemasan...';
    if (state is RecognizeSearchingComposition) {
      label = 'Mencari komposisi ${state.productName}...';
    }
    if (state is RecognizeAnalyzing) label = 'Menganalisis bahan...';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => _pickPackagingPhoto(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Foto Kemasan'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.push('/scan'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
            child: const Text('Foto Komposisi Manual'),
          ),
        ],
      ),
    );
  }
}
