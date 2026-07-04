import '../../../models/analysis_result.dart';

abstract class RecognizeState {
  const RecognizeState();
}

class RecognizeInitial extends RecognizeState {
  const RecognizeInitial();
}

class RecognizeAnalyzingPhoto extends RecognizeState {
  const RecognizeAnalyzingPhoto();
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
