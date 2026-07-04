import '../../../models/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool isSending;
  final String? errorMessage;

  const ChatState({
    this.messages = const [],
    this.isSending = false,
    this.errorMessage,
  });

  // Catatan: errorMessage TIDAK sticky seperti messages/isSending — tiap
  // copyWith mengganti errorMessage ke null kecuali dinyatakan eksplisit,
  // supaya error lama otomatis hilang begitu ada aksi baru (kirim/retry).
  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isSending,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
    );
  }
}
