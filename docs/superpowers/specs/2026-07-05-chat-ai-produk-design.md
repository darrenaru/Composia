# Design: Chat AI tentang Produk yang Dianalisis

Status: Approved
Tanggal: 2026-07-05

## Latar Belakang

Setelah Composia menganalisis sebuah produk (nama, kategori, ringkasan, daftar bahan + safety level), pengguna sering punya pertanyaan lanjutan yang tidak terjawab di tampilan statis — misalnya "apakah aman dipakai ibu hamil?" atau "kenapa bahan X dianggap perlu perhatian?". Fitur ini menambahkan chat AI per hasil analisis, diakses dari tab Ringkasan, supaya pengguna bisa bertanya langsung dan mendapat jawaban kontekstual dari data yang sudah dianalisis.

## Cakupan

- **Sumber jawaban**: hanya data analisis yang sudah tersimpan (nama produk, kategori, ringkasan, catatan keamanan, daftar bahan dengan safety level & alasan). **Tidak** memakai Google Search grounding — lebih cepat dan tidak menambah kuota API per pesan.
- **Penyimpanan**: permanen, disimpan sebagai bagian dari `AnalysisResult` yang sama (bukan storage terpisah), supaya otomatis ikut terhapus kalau hasil analisisnya dihapus dari riwayat.
- **Entry point**: tombol "Tanya AI" di tab Ringkasan (`ResultScreen`), di bawah `ProductSummaryCard`. Tombol tetap muncul walau `ingredients` kosong — AI tetap bisa menjawab pertanyaan umum dari nama/kategori produk yang ada.
- **Layar**: halaman chat penuh layar terpisah (bukan kotak chat tertanam di tab Ringkasan), supaya ada ruang cukup untuk mengetik dan scroll riwayat percakapan.

## Model Data

### `ChatMessage` (baru — `lib/models/chat_message.dart`)

```dart
enum ChatRole { user, model }

class ChatMessage {
  final ChatRole role;
  final String text;
  final DateTime timestamp;

  const ChatMessage({required this.role, required this.text, required this.timestamp});

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] == 'user' ? ChatRole.user : ChatRole.model,
        text: json['text'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
      );

  Map<String, dynamic> toJson() => {
        'role': role == ChatRole.user ? 'user' : 'model',
        'text': text,
        'timestamp': timestamp.toIso8601String(),
      };
}
```

### `AnalysisResult` (modifikasi — `lib/models/analysis_result.dart`)

- Field baru: `final List<ChatMessage> chatMessages;` — default `const []` di constructor.
- `fromJson`: `(json['chat_messages'] as List<dynamic>? ?? []).map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList()` — backward-compatible, data lama tanpa field ini otomatis jadi list kosong.
- `toJson`: tambah `'chat_messages': chatMessages.map((m) => m.toJson()).toList()`.
- Perlu tambah method `copyWith` sederhana (atau constructor baru manual) khusus untuk field `chatMessages`, dipakai saat append pesan baru tanpa mengubah field lain.

## Backend: `GeminiService.chat()`

Method baru di `lib/services/gemini_service.dart`, memakai `_post()` yang sudah ada (otomatis dapat fallback multi-API-key & retry-on-429 tanpa kode tambahan):

```dart
Future<String> chat({
  required AnalysisResult context,
  required List<ChatMessage> history,
  required String newMessage,
}) async {
  final contextPrompt = _buildChatContextPrompt(context);

  final contents = [
    {'role': 'user', 'parts': [{'text': contextPrompt}]},
    {'role': 'model', 'parts': [{'text': 'Baik, saya siap menjawab pertanyaan tentang produk ini.'}]},
    ...history.map((m) => {
      'role': m.role == ChatRole.user ? 'user' : 'model',
      'parts': [{'text': m.text}],
    }),
    {'role': 'user', 'parts': [{'text': newMessage}]},
  ];

  final requestBody = {'contents': contents};
  final response = await _post(requestBody);

  if (response.statusCode != 200) {
    final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
    final errorMsg = (errorBody['error'] as Map<String, dynamic>?)?['message'] as String? ?? 'API Error ${response.statusCode}';
    throw GeminiException(errorMsg, response.statusCode);
  }

  final responseData = jsonDecode(response.body) as Map<String, dynamic>;
  final candidates = responseData['candidates'] as List<dynamic>;
  final parts = (candidates.first as Map<String, dynamic>)['content']['parts'] as List<dynamic>;
  return (parts.first as Map<String, dynamic>)['text'] as String;
}
```

`_buildChatContextPrompt(AnalysisResult context)` — private helper yang merangkai nama produk, kategori, ringkasan, catatan keamanan, dan daftar bahan (nama + safety level + alasan) jadi satu blok teks instruksi dalam Bahasa Indonesia, ditutup dengan instruksi "Jawab pertanyaan pengguna tentang produk ini berdasarkan data di atas saja. Kalau pertanyaan di luar data yang tersedia, katakan dengan jujur bahwa informasi itu tidak ada dalam hasil analisis."

Catatan: **tidak** memakai `generationConfig.responseMimeType: application/json` (beda dari method analisis lain) karena jawaban chat adalah teks bebas, bukan struktur JSON.

## UI: `ChatScreen` + `ChatBloc`

Pola sama seperti `RecognizeBloc`/`RecognizeScreen` yang sudah ada.

- File baru: `lib/features/chat/bloc/chat_bloc.dart`, `chat_event.dart`, `chat_state.dart`, `lib/features/chat/chat_screen.dart`.
- **Event**: `ChatMessageSent(String text)`.
- **State**: `ChatState { List<ChatMessage> messages, bool isSending, String? errorMessage }` — satu state class dengan flag, bukan sealed class terpisah per status (percakapan butuh render list yang sama terus-menerus sambil status berubah, beda dari alur Recognize yang gonta-ganti tampilan penuh per state).
- Kirim pesan → tambahkan `ChatMessage(role: user)` ke state (optimistic), set `isSending: true` → panggil `GeminiService.chat()` → sukses: tambahkan `ChatMessage(role: model)`, panggil `storageService.saveToHistory(result.copyWith(chatMessages: updatedMessages))`; gagal: set `errorMessage`, tampilkan bubble error dengan tombol "Coba Lagi" khusus pesan itu (tidak memblokir seluruh layar chat).
- **UI**: `CustomAppBar` (judul = nama produk), `ListView` bubble chat (bubble kanan untuk user, kiri untuk AI — pola warna dari `AppColors.primary`/`AppColors.surfaceLight` seperti komponen lain), input teks + tombol kirim di bawah (`SafeArea` + `TextField` + `IconButton`, mirip pola input custom-allergen di `allergy_profile_screen.dart`).

## Routing

- `app_router.dart` tambah `GoRoute(path: '/result/:id/chat', builder: (context, state) => ChatScreen(resultId: ..., storageService: ...))` — top-level, di luar shell (full-screen, sama seperti `/compare`, `/allergy-profile`).
- `ResultScreen` tab Ringkasan tambah tombol "Tanya AI" di bawah `ProductSummaryCard`, `onTap: () => context.push('/result/${result.id}/chat')`.

## Error Handling

Reuse `GeminiException` yang sudah ada (`isRateLimitError`, `isAuthError`, `isServerError`) — sama seperti pola di `ScanScreen._showError`. Pesan error tampil sebagai bubble kecil di posisi pesan yang gagal terkirim, dengan tombol "Coba Lagi" yang mengirim ulang teks yang sama, bukan `SnackBar` yang menutupi seluruh layar (chat perlu tetap terlihat).

## Testing

- `test/chat_message_test.dart` (baru): `ChatMessage.fromJson`/`toJson` roundtrip, termasuk kasus role user & model.
- `test/analysis_result_test.dart` kalau belum ada, atau tambah ke test yang relevan: `AnalysisResult.fromJson` dengan data lama (tanpa field `chat_messages`) tetap menghasilkan `chatMessages: []` (backward-compat).
- Mengikuti konvensi yang sudah ada di proyek ini: `GeminiService` tidak diuji di level jaringan (tidak ada test untuk `analyzeIngredients`/`analyzePhoto` sekarang), jadi `chat()` juga tidak diberi unit test jaringan baru — diverifikasi manual di device.

## Di Luar Cakupan (YAGNI)

- Tidak ada Google Search grounding di dalam chat (beda dari `searchCompositionByWeb` yang sudah ada untuk use case lain).
- Tidak ada batas panjang riwayat chat / ringkasan otomatis kalau percakapan panjang — kalau nanti jadi masalah nyata (prompt kepanjangan), baru ditangani.
- Tidak ada fitur hapus/edit pesan individual — hapus chat hanya lewat hapus keseluruhan hasil analisis dari riwayat.
- Tidak ada streaming response (jawaban muncul bertahap) — konsisten dengan keputusan sebelumnya untuk tetap pakai HTTP manual, bukan SDK.
