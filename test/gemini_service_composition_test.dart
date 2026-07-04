import 'package:flutter_test/flutter_test.dart';
import 'package:composia/services/gemini_service.dart';

void main() {
  test('isCompositionNotFound returns true for exact sentinel', () {
    expect(isCompositionNotFound('TIDAK_DITEMUKAN'), isTrue);
  });

  test('isCompositionNotFound returns true when sentinel has surrounding whitespace', () {
    expect(isCompositionNotFound('  TIDAK_DITEMUKAN  \n'), isTrue);
  });

  test('isCompositionNotFound returns false for actual composition text', () {
    expect(isCompositionNotFound('Aqua, Glycerin, Parfum'), isFalse);
  });
}
