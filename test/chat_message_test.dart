import 'package:flutter_test/flutter_test.dart';
import 'package:composia/models/chat_message.dart';

void main() {
  test('ChatMessage toJson/fromJson roundtrip for user role', () {
    final message = ChatMessage(
      role: ChatRole.user,
      text: 'Apakah aman untuk kulit sensitif?',
      timestamp: DateTime(2026, 7, 5, 10, 30),
    );

    final restored = ChatMessage.fromJson(message.toJson());

    expect(restored.role, ChatRole.user);
    expect(restored.text, 'Apakah aman untuk kulit sensitif?');
    expect(restored.timestamp, DateTime(2026, 7, 5, 10, 30));
  });

  test('ChatMessage toJson/fromJson roundtrip for model role', () {
    final message = ChatMessage(
      role: ChatRole.model,
      text: 'Berdasarkan data analisis, produk ini tergolong aman.',
      timestamp: DateTime(2026, 7, 5, 10, 31),
    );

    final restored = ChatMessage.fromJson(message.toJson());

    expect(restored.role, ChatRole.model);
    expect(restored.text, 'Berdasarkan data analisis, produk ini tergolong aman.');
  });

  test('ChatMessage.fromJson defaults unknown role string to model', () {
    final restored = ChatMessage.fromJson({
      'role': 'something_unexpected',
      'text': 'x',
      'timestamp': '2026-07-05T10:30:00.000',
    });

    expect(restored.role, ChatRole.model);
  });
}
