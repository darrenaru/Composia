import 'dart:io';
import '../../../models/analysis_result.dart';

abstract class ScanState {
  const ScanState();
}

class ScanInitial extends ScanState {
  const ScanInitial();
}

class ScanImageLoading extends ScanState {
  const ScanImageLoading();
}

class ScanImageReady extends ScanState {
  final File image;
  const ScanImageReady(this.image);
}

class ScanAnalyzing extends ScanState {
  final File image;
  const ScanAnalyzing(this.image);
}

class ScanSuccess extends ScanState {
  final AnalysisResult result;
  const ScanSuccess(this.result);
}

class ScanError extends ScanState {
  final String message;
  final bool isApiKeyError;
  const ScanError(this.message, {this.isApiKeyError = false});
}
