import 'package:flutter_test/flutter_test.dart';
import 'package:composia/models/analysis_result.dart';
import 'package:composia/models/chat_message.dart';
import 'package:composia/models/ingredient.dart';

AnalysisResult _baseResult() {
  return AnalysisResult(
    id: '1',
    productName: 'Produk Tes',
    category: ProductCategory.general,
    summary: 'ringkasan',
    overallSafetyNote: 'catatan',
    overallSafetyLevel: SafetyLevel.safe,
    ingredients: const [],
    analyzedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  test('fromJson without chat_messages defaults to empty list (backward-compat)', () {
    final json = _baseResult().toJson()..remove('chat_messages');

    final restored = AnalysisResult.fromJson(json);

    expect(restored.chatMessages, isEmpty);
  });

  test('toJson/fromJson roundtrip preserves chatMessages', () {
    final withChat = _baseResult().copyWith(chatMessages: [
      ChatMessage(role: ChatRole.user, text: 'Halo', timestamp: DateTime(2026, 1, 1, 8)),
      ChatMessage(role: ChatRole.model, text: 'Halo juga', timestamp: DateTime(2026, 1, 1, 8, 1)),
    ]);

    final restored = AnalysisResult.fromJson(withChat.toJson());

    expect(restored.chatMessages.length, 2);
    expect(restored.chatMessages.first.role, ChatRole.user);
    expect(restored.chatMessages.last.text, 'Halo juga');
  });

  test('copyWith without chatMessages keeps existing messages', () {
    final withChat = _baseResult().copyWith(chatMessages: [
      ChatMessage(role: ChatRole.user, text: 'Halo', timestamp: DateTime(2026, 1, 1)),
    ]);

    final unchanged = withChat.copyWith();

    expect(unchanged.chatMessages.length, 1);
  });
}
