import 'dart:io';

abstract class RecognizeEvent {
  const RecognizeEvent();
}

class PhotoTaken extends RecognizeEvent {
  final File image;
  const PhotoTaken(this.image);
}
