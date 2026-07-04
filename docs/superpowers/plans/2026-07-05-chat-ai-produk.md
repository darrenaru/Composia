# Chat AI Produk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tambahkan chat AI per hasil analisis, diakses dari tombol "Tanya AI" di tab Ringkasan (`ResultScreen`), supaya pengguna bisa bertanya lanjutan tentang produk yang sudah dianalisis.

**Architecture:** Model `ChatMessage` baru disimpan sebagai field `chatMessages` di `AnalysisResult` yang sudah ada (persist lewat `StorageService.saveToHistory` yang sudah ada, tanpa storage key baru). `GeminiService` dapat method `chat()` baru yang memakai `_post()` (retry-on-429 multi-key) yang sudah ada. UI mengikuti pola `RecognizeBloc`/`RecognizeScreen` yang sudah ada di codebase: `ChatBloc` di-provide lewat route builder, `ChatScreen` full-screen di-push dari tombol di Ringkasan.

**Tech Stack:** Flutter, `flutter_bloc`, `go_router`, `http` (sudah semua ada di `pubspec.yaml`, tidak ada dependency baru).

## Global Constraints

- Sumber jawaban chat: hanya data analisis yang sudah ada (nama produk, kategori, ringkasan, catatan keamanan, daftar bahan+safety level). Tidak memakai Google Search grounding.
- Penyimpanan chat permanen, sebagai bagian dari `AnalysisResult` yang sama (bukan storage key terpisah).
- Layar chat adalah halaman penuh layar terpisah (route `/result/:id/chat`), bukan kotak inline di tab Ringkasan.
- Tombol "Tanya AI" tetap muncul walau `ingredients` kosong.
- Tidak ada Google Search grounding, tidak ada streaming response, tidak ada batas panjang riwayat chat, tidak ada hapus/edit pesan individual (spec: `docs/superpowers/specs/2026-07-05-chat-ai-produk-design.md`, bagian "Di Luar Cakupan").
- Mengikuti konvensi proyek: `GeminiService` tidak diuji di level jaringan (tidak ada `MockClient` untuk method analisis lain) — `chat()` juga tidak diberi unit test jaringan baru, diverifikasi manual di device.

---

### Task 1: Model `ChatMessage`

**Files:**
- Create: `lib/models/chat_message.dart`
- Test: `test/chat_message_test.dart`

**Interfaces:**
- Produces: `enum ChatRole { user, model }`; `class ChatMessage { final ChatRole role; final String text; final DateTime timestamp; }` dengan `ChatMessage.fromJson(Map<String, dynamic>)` dan `Map<String, dynamic> toJson()`.

- [ ] **Step 1: Write the failing test**

```dart
// test/chat_message_test.dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/chat_message_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'composia' in 'package:composia/models/chat_message.dart'` atau `Target of URI doesn't exist` (file belum ada).

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/models/chat_message.dart
enum ChatRole { user, model }

class ChatMessage {
  final ChatRole role;
  final String text;
  final DateTime timestamp;

  const ChatMessage({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] == 'user' ? ChatRole.user : ChatRole.model,
      text: json['text'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'role': role == ChatRole.user ? 'user' : 'model',
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/chat_message_test.dart`
Expected: `00:00 +3: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/chat_message.dart test/chat_message_test.dart
git commit -m "feat: add ChatMessage model for AI chat feature"
```

---

### Task 2: Tambah `chatMessages` + `copyWith` ke `AnalysisResult`

**Files:**
- Modify: `lib/models/analysis_result.dart`
- Test: `test/analysis_result_test.dart` (baru)

**Interfaces:**
- Consumes: `ChatMessage`, `ChatMessage.fromJson`, `ChatMessage.toJson` (Task 1).
- Produces: `AnalysisResult.chatMessages` (`List<ChatMessage>`, default `const []`); `AnalysisResult copyWith({List<ChatMessage>? chatMessages})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/analysis_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:composia/models/analysis_result.dart';
import 'package:composia/models/chat_message.dart';

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/analysis_result_test.dart`
Expected: FAIL — `The method 'copyWith' isn't defined for the type 'AnalysisResult'` (compile error, `copyWith` belum ada).

- [ ] **Step 3: Write minimal implementation**

Edit `lib/models/analysis_result.dart` — tambah import di baris 2 (setelah `import 'ingredient.dart';`):

```dart
import 'chat_message.dart';
```

Ganti field list dan constructor (baris 14-37 saat ini):

```dart
class AnalysisResult {
  final String id;
  final String? productName;
  final ProductCategory category;
  final String summary;
  final String overallSafetyNote;
  final SafetyLevel overallSafetyLevel;
  final List<Ingredient> ingredients;
  final DateTime analyzedAt;
  final String? imagePath;
  final String? recommendation;
  final List<ChatMessage> chatMessages;

  const AnalysisResult({
    required this.id,
    this.productName,
    required this.category,
    required this.summary,
    required this.overallSafetyNote,
    required this.overallSafetyLevel,
    required this.ingredients,
    required this.analyzedAt,
    this.imagePath,
    this.recommendation,
    this.chatMessages = const [],
  });

  AnalysisResult copyWith({List<ChatMessage>? chatMessages}) {
    return AnalysisResult(
      id: id,
      productName: productName,
      category: category,
      summary: summary,
      overallSafetyNote: overallSafetyNote,
      overallSafetyLevel: overallSafetyLevel,
      ingredients: ingredients,
      analyzedAt: analyzedAt,
      imagePath: imagePath,
      recommendation: recommendation,
      chatMessages: chatMessages ?? this.chatMessages,
    );
  }
```

Di `factory AnalysisResult.fromJson(...)`, tambah field baru sebelum tanda kurung tutup `);` (setelah `recommendation: json['recommendation'] as String?,`):

```dart
      recommendation: json['recommendation'] as String?,
      chatMessages: (json['chat_messages'] as List<dynamic>? ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
```

Di `Map<String, dynamic> toJson()`, tambah entry baru setelah `'recommendation': recommendation,`:

```dart
        'recommendation': recommendation,
        'chat_messages': chatMessages.map((m) => m.toJson()).toList(),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/analysis_result_test.dart`
Expected: `00:00 +3: All tests passed!`

- [ ] **Step 5: Run full test suite to check no regression**

Run: `flutter test`
Expected: all existing tests (16 sebelumnya + yang baru) tetap pass.

- [ ] **Step 6: Commit**

```bash
git add lib/models/analysis_result.dart test/analysis_result_test.dart
git commit -m "feat: add chatMessages field and copyWith to AnalysisResult"
```

---

### Task 3: `GeminiService.chat()`

**Files:**
- Modify: `lib/services/gemini_service.dart`

**Interfaces:**
- Consumes: `ChatMessage`, `ChatRole` (Task 1); `AnalysisResult.chatMessages` (Task 2); `_post(Map<String, dynamic> requestBody)` (sudah ada, baris 46-58); `GeminiException` (sudah ada).
- Produces: `Future<String> chat({required AnalysisResult context, required List<ChatMessage> history, required String newMessage})`.

Tidak ada test jaringan baru untuk task ini (lihat Global Constraints) — verifikasi lewat `flutter analyze` dan manual di device pada Task 7.

- [ ] **Step 1: Tambah import**

Di `lib/services/gemini_service.dart`, tambah import setelah `import '../models/ingredient.dart';` (baris 5):

```dart
import '../models/chat_message.dart';
```

- [ ] **Step 2: Tambah method `chat()` dan helper `_buildChatContextPrompt()`**

Tambahkan method baru tepat sebelum `String _buildAnalysisPrompt()` (cari baris `String _buildAnalysisPrompt() {`):

```dart
  Future<String> chat({
    required AnalysisResult context,
    required List<ChatMessage> history,
    required String newMessage,
  }) async {
    final contents = [
      {
        'role': 'user',
        'parts': [
          {'text': _buildChatContextPrompt(context)},
        ],
      },
      {
        'role': 'model',
        'parts': [
          {'text': 'Baik, saya siap menjawab pertanyaan tentang produk ini.'},
        ],
      },
      ...history.map((m) => {
            'role': m.role == ChatRole.user ? 'user' : 'model',
            'parts': [
              {'text': m.text},
            ],
          }),
      {
        'role': 'user',
        'parts': [
          {'text': newMessage},
        ],
      },
    ];

    final requestBody = {'contents': contents};
    final response = await _post(requestBody);

    if (response.statusCode != 200) {
      final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMsg =
          (errorBody['error'] as Map<String, dynamic>?)?['message']
                  as String? ??
              'API Error ${response.statusCode}';
      throw GeminiException(errorMsg, response.statusCode);
    }

    final responseData = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = responseData['candidates'] as List<dynamic>;
    final parts =
        (candidates.first as Map<String, dynamic>)['content']['parts']
            as List<dynamic>;
    return (parts.first as Map<String, dynamic>)['text'] as String;
  }

  String _buildChatContextPrompt(AnalysisResult context) {
    final ingredientLines = context.ingredients
        .map((i) => '- ${i.name} (level: ${i.safetyLevel.name}): ${i.safetyReason}')
        .join('\n');

    return '''
Kamu adalah asisten yang membantu pengguna memahami hasil analisis produk berikut. Jawab HANYA berdasarkan data di bawah ini. Kalau pertanyaan pengguna di luar data yang tersedia, katakan dengan jujur bahwa informasi itu tidak ada dalam hasil analisis ini.

Nama produk: ${context.productName ?? 'Tidak diketahui'}
Kategori: ${context.category.name}
Ringkasan: ${context.summary}
Catatan keamanan keseluruhan: ${context.overallSafetyNote}
Rekomendasi: ${context.recommendation ?? '-'}

Daftar bahan:
${ingredientLines.isEmpty ? '(tidak ada data bahan)' : ingredientLines}

Jawab dalam Bahasa Indonesia, singkat dan jelas.
''';
  }

```

- [ ] **Step 3: Verifikasi analyzer**

Run: `flutter analyze lib/services/gemini_service.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/services/gemini_service.dart
git commit -m "feat: add GeminiService.chat() for follow-up questions on analyzed products"
```

---

### Task 4: `ChatBloc` + `ChatEvent` + `ChatState`

**Files:**
- Create: `lib/features/chat/bloc/chat_event.dart`
- Create: `lib/features/chat/bloc/chat_state.dart`
- Create: `lib/features/chat/bloc/chat_bloc.dart`

**Interfaces:**
- Consumes: `GeminiService.chat()` (Task 3); `ChatMessage`, `ChatRole` (Task 1); `AnalysisResult.copyWith` (Task 2); `StorageService.getApiKeys()`, `StorageService.saveToHistory()` (sudah ada); `GeminiException` (sudah ada).
- Produces: `ChatEvent` (`ChatMessageSent(String text)`, `ChatRetryRequested()`); `ChatState { List<ChatMessage> messages, bool isSending, String? errorMessage }` dengan `copyWith`; `ChatBloc({required StorageService storageService, required AnalysisResult result})`.

- [ ] **Step 1: Buat `chat_event.dart`**

```dart
// lib/features/chat/bloc/chat_event.dart
abstract class ChatEvent {
  const ChatEvent();
}

class ChatMessageSent extends ChatEvent {
  final String text;
  const ChatMessageSent(this.text);
}

class ChatRetryRequested extends ChatEvent {
  const ChatRetryRequested();
}
```

- [ ] **Step 2: Buat `chat_state.dart`**

```dart
// lib/features/chat/bloc/chat_state.dart
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
```

- [ ] **Step 3: Buat `chat_bloc.dart`**

```dart
// lib/features/chat/bloc/chat_bloc.dart
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
```

- [ ] **Step 4: Verifikasi analyzer**

Run: `flutter analyze lib/features/chat/`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/features/chat/bloc/
git commit -m "feat: add ChatBloc for AI chat feature"
```

---

### Task 5: `ChatScreen` UI

**Files:**
- Create: `lib/features/chat/chat_screen.dart`

**Interfaces:**
- Consumes: `ChatBloc`, `ChatState`, `ChatEvent`, `ChatMessageSent`, `ChatRetryRequested` (Task 4); `AnalysisResult`, `ChatMessage`, `ChatRole` (Task 1/2); `CustomAppBar` (`lib/core/widgets/custom_app_bar.dart`, sudah ada); `AppColors` (sudah ada).

- [ ] **Step 1: Buat `chat_screen.dart`**

```dart
// lib/features/chat/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_app_bar.dart';
import '../../models/analysis_result.dart';
import '../../models/chat_message.dart';
import 'bloc/chat_bloc.dart';
import 'bloc/chat_event.dart';
import 'bloc/chat_state.dart';

class ChatScreen extends StatefulWidget {
  final AnalysisResult result;

  const ChatScreen({super.key, required this.result});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send(BuildContext context) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<ChatBloc>().add(ChatMessageSent(text));
    _controller.clear();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CustomAppBar(title: widget.result.productName ?? 'Tanya AI'),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) => _scrollToBottom(),
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: state.messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: state.messages.length,
                        itemBuilder: (context, i) =>
                            _buildBubble(context, state.messages[i]),
                      ),
              ),
              if (state.errorMessage != null)
                _buildErrorBanner(context, state.errorMessage!),
              if (state.isSending) _buildTypingIndicator(),
              _buildInputBar(context, state),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Tanya apa saja tentang produk ini — misalnya keamanannya untuk kondisi tertentu, atau alasan rating suatu bahan.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context, ChatMessage message) {
    final isUser = message.role == ChatRole.user;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: isUser ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.dangerRedLight,
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.dangerRed, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () =>
                context.read<ChatBloc>().add(const ChatRetryRequested()),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context, ChatState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !state.isSending,
                decoration: const InputDecoration(
                  hintText: 'Ketik pertanyaanmu...',
                ),
                onSubmitted: (_) => _send(context),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: state.isSending ? null : () => _send(context),
              icon: const Icon(Icons.send_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verifikasi analyzer**

Run: `flutter analyze lib/features/chat/`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/chat/chat_screen.dart
git commit -m "feat: add ChatScreen UI for AI chat feature"
```

---

### Task 6: Routing + tombol "Tanya AI" di Ringkasan

**Files:**
- Modify: `lib/router/app_router.dart`
- Modify: `lib/features/result/result_screen.dart`

**Interfaces:**
- Consumes: `ChatScreen`, `ChatBloc` (Task 4/5); `OutlineIconButton` (`lib/core/widgets/custom_button.dart`, sudah ada).

- [ ] **Step 1: Tambah import di `app_router.dart`**

Tambah setelah `import '../features/compare/compare_screen.dart';` (baris 5):

```dart
import '../features/chat/bloc/chat_bloc.dart';
import '../features/chat/chat_screen.dart';
```

- [ ] **Step 2: Tambah route baru**

Di `app_router.dart`, tambah route berikut tepat setelah blok `GoRoute(path: '/result/:id', ...)` (baris 78-84 saat ini), sebelum `GoRoute(path: '/allergy-profile', ...)`:

```dart
      GoRoute(
        path: '/result/:id/chat',
        builder: (context, state) {
          final result =
              storageService.getResultById(state.pathParameters['id']!);
          if (result == null) {
            return const Scaffold(
              body: Center(child: Text('Hasil tidak ditemukan')),
            );
          }
          return BlocProvider(
            create: (_) => ChatBloc(
              storageService: storageService,
              result: result,
            ),
            child: ChatScreen(result: result),
          );
        },
      ),
```

- [ ] **Step 3: Tambah tombol "Tanya AI" di `result_screen.dart`**

Tambah import setelah `import '../../core/widgets/custom_app_bar.dart';` (baris 9):

```dart
import '../../core/widgets/custom_button.dart';
```

Di method `_buildOverviewTab()`, ubah blok `_buildSection(child: ProductSummaryCard(result: result))` (baris 144-146 saat ini) supaya diikuti tombol baru:

```dart
          _buildSection(
            child: ProductSummaryCard(result: result),
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 16),
          OutlineIconButton(
            label: 'Tanya AI',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () => context.push('/result/${result.id}/chat'),
          ),
          const SizedBox(height: 80),
```

(Baris `const SizedBox(height: 80),` yang lama dihapus, digantikan oleh urutan baru di atas yang sudah menyertakan `SizedBox(height: 80)` di akhir.)

- [ ] **Step 4: Verifikasi analyzer**

Run: `flutter analyze lib/router/app_router.dart lib/features/result/result_screen.dart`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/router/app_router.dart lib/features/result/result_screen.dart
git commit -m "feat: wire up /result/:id/chat route and Tanya AI button"
```

---

### Task 7: QA Pass

**Files:** Tidak ada file baru — verifikasi menyeluruh atas Task 1-6.

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: 0 error baru (info/warning lama seperti `withOpacity` deprecated boleh tetap ada, sudah dikonfirmasi pre-existing sepanjang sesi-sesi sebelumnya).

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: semua test pass (16 test lama + test baru dari Task 1 & 2).

- [ ] **Step 3: Manual device walkthrough**

Pakai `run_local.sh -d <device_id>` (skrip lokal yang sudah ada, berisi 2 API key untuk fallback):
1. Buka hasil analisis apa saja dari Riwayat → tab Ringkasan → pastikan tombol "Tanya AI" muncul di bawah kartu ringkasan produk.
2. Tap "Tanya AI" → layar chat terbuka, judul = nama produk, area kosong menampilkan teks pancingan.
3. Ketik pertanyaan (mis. "kenapa bahan ini dianggap perlu perhatian?") → kirim → bubble user muncul kanan, indikator loading muncul, lalu bubble balasan AI muncul kiri.
4. Keluar dari layar chat (back) → masuk lagi ke chat produk yang sama → riwayat percakapan sebelumnya masih ada (verifikasi persist ke storage).
5. Buka hasil analisis lain yang `ingredients`-nya kosong (kalau ada) → pastikan tombol "Tanya AI" tetap muncul.
6. Matikan koneksi internet sesaat, kirim pesan → pastikan bubble error + tombol "Coba Lagi" muncul tanpa memblokir seluruh layar; nyalakan lagi internet, tap "Coba Lagi" → balasan AI muncul tanpa duplikat bubble pertanyaan user.

- [ ] **Step 4: Bersihkan entri tes dari riwayat (kalau ada) dan push**

```bash
git push origin main
```
