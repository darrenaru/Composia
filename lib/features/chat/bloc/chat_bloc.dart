import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/analysis_result.dart';
import '../../../models/chat_message.dart';
import '../../../services/gemini_service.dart';
import '../../../services/storage_service.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final StorageService storageService;
  final AnalysisResult result;

  ChatBloc({required this.storageService, required this.result})
      : super(ChatState(messages: result.chatMessages)) {
    on<ChatMessageSent>(_onMessageSent);
    on<ChatRetryRequested>(_onRetryRequested);
  }

  Future<void> _onMessageSent(
      ChatMessageSent event, Emitter<ChatState> emit) async {
    final history = state.messages;
    final userMessage = ChatMessage(
      role: ChatRole.user,
      text: event.text,
      timestamp: DateTime.now(),
    );
    final withUserMessage = [...history, userMessage];
    emit(state.copyWith(messages: withUserMessage, isSending: true));

    await _sendAndAppendReply(
      emit,
      history: history,
      newMessage: event.text,
      messagesIfFailed: withUserMessage,
    );
  }

  Future<void> _onRetryRequested(
      ChatRetryRequested event, Emitter<ChatState> emit) async {
    if (state.messages.isEmpty ||
        state.messages.last.role != ChatRole.user) {
      return;
    }
    final lastUserMessage = state.messages.last;
    final history = state.messages.sublist(0, state.messages.length - 1);
    emit(state.copyWith(isSending: true));

    await _sendAndAppendReply(
      emit,
      history: history,
      newMessage: lastUserMessage.text,
      messagesIfFailed: state.messages,
    );
  }

  Future<void> _sendAndAppendReply(
    Emitter<ChatState> emit, {
    required List<ChatMessage> history,
    required String newMessage,
    required List<ChatMessage> messagesIfFailed,
  }) async {
    final geminiService = GeminiService(apiKeys: storageService.getApiKeys());
    try {
      final reply = await geminiService.chat(
        context: result,
        history: history,
        newMessage: newMessage,
      );
      final aiMessage = ChatMessage(
        role: ChatRole.model,
        text: reply,
        timestamp: DateTime.now(),
      );
      final finalMessages = [...messagesIfFailed, aiMessage];
      await storageService.saveToHistory(
        result.copyWith(chatMessages: finalMessages),
      );
      emit(state.copyWith(messages: finalMessages, isSending: false));
    } on GeminiException catch (e) {
      emit(state.copyWith(
        messages: messagesIfFailed,
        isSending: false,
        errorMessage: _friendlyError(e),
      ));
    }
  }

  String _friendlyError(GeminiException e) {
    if (e.isAuthError) {
      return 'API Key tidak valid. Periksa kembali API Key di Pengaturan.';
    }
    if (e.isRateLimitError) {
      return 'Terlalu banyak permintaan. Tunggu sebentar dan coba lagi.';
    }
    return 'Gagal mengirim pesan: ${e.message}';
  }
}
