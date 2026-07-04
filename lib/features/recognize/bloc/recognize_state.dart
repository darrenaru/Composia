import 'dart:io';
import '../../../models/analysis_result.dart';

abstract class RecognizeState {
  const RecognizeState();
}

class RecognizeInitial extends RecognizeState {
  const RecognizeInitial();
}

class RecognizeLookingUp extends RecognizeState {
  const RecognizeLookingUp();
}

class RecognizeIdentifying extends RecognizeState {
  final File image;
  const RecognizeIdentifying(this.image);
}

class RecognizeSearchingComposition extends RecognizeState {
  final String productName;
  const RecognizeSearchingComposition(this.productName);
}

class RecognizeAnalyzing extends RecognizeState {
  const RecognizeAnalyzing();
}

class RecognizeSuccess extends RecognizeState {
  final AnalysisResult result;
  const RecognizeSuccess(this.result);
}

class RecognizeNotFound extends RecognizeState {
  const RecognizeNotFound();
}

class RecognizeError extends RecognizeState {
  final String message;
  const RecognizeError(this.message);
}
