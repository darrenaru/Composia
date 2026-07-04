import 'dart:io';

abstract class RecognizeEvent {
  const RecognizeEvent();
}

class BarcodeDetected extends RecognizeEvent {
  final String code;
  const BarcodeDetected(this.code);
}

class PackagingPhotoCaptured extends RecognizeEvent {
  final File image;
  const PackagingPhotoCaptured(this.image);
}
