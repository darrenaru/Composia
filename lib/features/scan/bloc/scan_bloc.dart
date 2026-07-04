import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../services/gemini_service.dart';
import '../../../services/storage_service.dart';
import 'scan_event.dart';
import 'scan_state.dart';

class ScanBloc extends Bloc<ScanEvent, ScanState> {
  final StorageService storageService;
  final ImagePicker _picker = ImagePicker();
  static const _uuid = Uuid();

  ScanBloc({required this.storageService}) : super(const ScanInitial()) {
    on<ScanImageFromCamera>(_onFromCamera);
    on<ScanImageFromGallery>(_onFromGallery);
    on<ScanImageSelected>(_onImageSelected);
    on<ScanImageCleared>(_onImageCleared);
    on<ScanAnalyzeRequested>(_onAnalyzeRequested);
  }

  Future<void> _onFromCamera(
      ScanImageFromCamera event, Emitter<ScanState> emit) async {
    emit(const ScanImageLoading());
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked != null) {
        emit(ScanImageReady(File(picked.path)));
      } else {
        emit(const ScanInitial());
      }
    } catch (e) {
      emit(ScanError('Tidak dapat membuka kamera: $e'));
    }
  }

  Future<void> _onFromGallery(
      ScanImageFromGallery event, Emitter<ScanState> emit) async {
    emit(const ScanImageLoading());
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked != null) {
        emit(ScanImageReady(File(picked.path)));
      } else {
        emit(const ScanInitial());
      }
    } catch (e) {
      emit(ScanError('Tidak dapat membuka galeri: $e'));
    }
  }

  void _onImageSelected(ScanImageSelected event, Emitter<ScanState> emit) {
    emit(ScanImageReady(event.image));
  }

  void _onImageCleared(ScanImageCleared event, Emitter<ScanState> emit) {
    emit(const ScanInitial());
  }

  Future<void> _onAnalyzeRequested(
      ScanAnalyzeRequested event, Emitter<ScanState> emit) async {
    final currentState = state;
    if (currentState is! ScanImageReady) return;

    emit(ScanAnalyzing(currentState.image));

    try {
      final geminiService = GeminiService(apiKeys: storageService.getApiKeys());
      final resultId = _uuid.v4();

      final result = await geminiService.analyzeIngredients(
        imageFile: currentState.image,
        resultId: resultId,
      );

      await storageService.saveToHistory(result);
      emit(ScanSuccess(result));
    } on GeminiException catch (e) {
      if (e.isAuthError) {
        emit(const ScanError(
          'API Key tidak valid. Periksa kembali API Key di Pengaturan.',
          isApiKeyError: true,
        ));
      } else if (e.isRateLimitError) {
        emit(ScanError(e.rateLimitMessage));
      } else {
        emit(ScanError('Gagal menganalisis: ${e.message}'));
      }
    } catch (e) {
      emit(ScanError('Terjadi kesalahan: $e'));
    }
  }
}
