import 'dart:io';

abstract class ScanEvent {
  const ScanEvent();
}

class ScanImageFromCamera extends ScanEvent {
  const ScanImageFromCamera();
}

class ScanImageFromGallery extends ScanEvent {
  const ScanImageFromGallery();
}

class ScanImageSelected extends ScanEvent {
  final File image;
  const ScanImageSelected(this.image);
}

class ScanImageCleared extends ScanEvent {
  const ScanImageCleared();
}

class ScanAnalyzeRequested extends ScanEvent {
  const ScanAnalyzeRequested();
}
