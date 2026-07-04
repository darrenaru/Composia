# Design: Profil Alergi Personal & Bandingkan 2 Produk

Status: Approved
Tanggal: 2026-07-04

## Latar Belakang

Composia saat ini menganalisis label produk lewat Gemini dan menyimpan hasilnya di riwayat lokal (`StorageService` + `SharedPreferences`). Dua fitur baru diminta:

1. Profil alergi personal — highlight bahan yang cocok dengan sensitivitas user, bukan flag generik `is_common_allergen` yang sama untuk semua orang.
2. Bandingkan 2 produk dari riwayat — bantu user memutuskan mana yang lebih aman.

Kedua fitur murni client-side (tidak menambah pemanggilan Gemini API atau biaya), bekerja retroaktif terhadap riwayat yang sudah ada.

## Fitur 1: Profil Alergi Personal

### Data & Storage

- `StorageService` tambah:
  - `List<String> getAllergyProfile()` — baca `StringList` dari key `composia_allergy_profile`, default `[]`.
  - `Future<void> setAllergyProfile(List<String> terms)` — simpan (lowercase, trim, dedup).
- Tidak ada model class baru — cukup `List<String>`.

### UI: Layar Profil Alergi

- File baru: `lib/features/settings/allergy_profile_screen.dart`, route `/allergy-profile`.
- Diakses dari card baru "Profil Alergi" di `settings_screen.dart` (di atas "Tentang Composia").
- Daftar bahan umum sebagai `FilterChip` yang bisa dicentang/lepas langsung (auto-save tiap toggle, tanpa tombol simpan terpisah):
  Fragrance/Parfum, Paraben, Sulfate (SLS/SLES), Alcohol Denat, Silicone, Nikel, Pewarna (CI), Formaldehyde releaser.
- Kolom teks + tombol tambah untuk bahan custom di luar daftar umum → jadi chip tambahan yang bisa dihapus (icon `x`).
- Semua perubahan langsung persist via `setAllergyProfile`.

### Matching Logic

- Helper murni (bisa jadi top-level function atau static method), contoh lokasi: `lib/core/utils/allergy_matcher.dart`.
- `bool ingredientMatchesAllergyProfile(Ingredient ingredient, List<String> profile)`:
  untuk tiap `term` di `profile` (lowercase), cocok jika
  `ingredient.name.toLowerCase().contains(term) || (ingredient.inci?.toLowerCase().contains(term) ?? false)`.
- Batasan yang disadari (bukan bug): pencocokan berbasis substring nama, bukan pemetaan kimia/sinonim. "Fragrance" tidak otomatis cocok dengan "Parfum" kecuali user daftarkan keduanya.

### Tampilan di Result Screen

- `ResultScreen` ambil `storageService.getAllergyProfile()` saat load, hitung daftar ingredient yang match.
- Tab "Daftar Bahan": `IngredientCard` dapat parameter baru `bool matchesAllergyProfile` → kalau true, border merah + chip "Cocok Profil Alergimu" (terpisah visual dari chip "Alergen" generik yang sudah ada).
- Tab "Ringkasan": banner baru di atas (tampil hanya jika ada match) — "⚠️ N bahan cocok dengan profil alergimu: nama1, nama2, ...".

## Fitur 2: Bandingkan 2 Produk

### Alur Pemilihan (History Screen)

- `history_screen.dart` tambah tombol "Bandingkan" (icon `compare_arrows`) di app bar → toggle `_selectionMode`.
- Saat `_selectionMode` aktif:
  - Tiap `_HistoryCard` menampilkan checkbox overlay, tap = toggle pilih (bukan buka detail).
  - Maksimal 2 item terpilih; tap ke-3 menampilkan snackbar "Maksimal 2 produk untuk dibandingkan".
  - Saat tepat 2 terpilih, tombol bawah "Bandingkan (2)" muncul → navigasi ke `/compare/:idA/:idB`.
  - Swipe-to-delete (`Dismissible`) dimatikan sementara selama `_selectionMode` aktif, supaya tidak bentrok dengan gesture pilih checkbox.

### Layar Bandingkan

- File baru: `lib/features/compare/compare_screen.dart`, route `/compare/:idA/:idB`.
- Ambil kedua `AnalysisResult` via `storageService.getResultById`.
- Header 2 kolom berdampingan: icon kategori, nama produk, `SafetyBadge` overall level.
- Verdict satu baris di bawah header, dihitung dari skor rata-rata keparahan bahan:
  `safe=0, caution=1, warning=2, danger=3, unknown=1`, dirata-rata per produk (bukan dijumlah, supaya adil untuk jumlah bahan yang beda).
  - Selisih skor > 0.3 → "✅ [Nama Produk] lebih aman" (skor lebih rendah menang).
  - Selisih ≤ 0.3 → "⚖️ Kira-kira setara".
- Daftar gabungan: union bahan unik dari kedua produk (key: `name.toLowerCase().trim()`), urut alfabet. Tiap baris: nama bahan + 2 indikator (badge warna level keamanan di produk A / produk B, atau "-" kalau tidak ada di produk itu).
- Batasan yang disadari: pencocokan bahan antar produk berbasis nama persis (lowercase) — bahan yang secara kimia sama tapi ditulis beda oleh Gemini di dua hasil analisis akan dianggap dua bahan berbeda.

### Router

- `app_router.dart` tambah 2 route: `/allergy-profile`, `/compare/:idA/:idB`.

## Testing

- Ponytail-style self-check (bukan test suite penuh): tambah `test/allergy_matcher_test.dart` — assert dasar untuk `ingredientMatchesAllergyProfile` (match substring nama, match via inci, tidak match kalau profil kosong).
- Verifikasi manual di device (sudah ada alur `flutter run` + adb screenshot dari sesi sebelumnya): cek highlight alergi di Result screen, dan alur pilih-2-lalu-bandingkan di History → Compare.

## Di Luar Cakupan (YAGNI)

- Tidak ada sinonim/ontologi kimia untuk matching (mis. INCI database eksternal).
- Tidak ada batas jumlah produk dibandingkan lebih dari 2.
- Tidak ada perubahan pada prompt Gemini atau `GeminiService` — kedua fitur murni post-processing lokal.
