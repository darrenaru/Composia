# Design: Product Recognition (Barcode & Packaging Photo)

Status: Approved
Tanggal: 2026-07-04

## Latar Belakang

Composia saat ini hanya bisa menganalisis produk lewat foto label komposisi (OCR + reasoning via Gemini vision). User ingin jalur tambahan: foto/scan **kemasan produk** (bukan label bahan), sistem mengenali produknya, lalu otomatis mencari data komposisinya — tanpa user harus memfoto label bahan secara langsung.

Fitur ini murni **jalur tambahan di depan** alur yang sudah ada. Jalur manual (foto label komposisi) tidak diubah sama sekali dan selalu tersedia sebagai fallback akhir.

## Arsitektur

Fitur baru diisolasi total di `lib/features/recognize/` (route baru `/recognize`), **tanpa mengubah** `ScanBloc`, `scan_screen.dart`, `scan_event.dart`, atau `scan_state.dart` yang sudah ada dan sudah teruji. Home (`_pushScan` di `home_screen.dart`) diarahkan ke `/recognize` sebagai entry point baru; layar itu punya jalan keluar eksplisit ke `/scan` (alur manual lama, tidak berubah) kapan pun user mau, dan otomatis mengarah ke sana kalau semua jalur otomatis gagal.

Prinsip: setiap jalur (barcode, foto kemasan) berakhir di satu titik yang sama — teks komposisi mentah — yang lalu diproses lewat method baru `GeminiService.analyzeIngredientsFromText()` untuk menghasilkan `AnalysisResult` yang **identik strukturnya** dengan hasil dari foto label, sehingga ResultScreen, History, Compare, dan Profil Alergi yang sudah dibangun tidak perlu diubah sama sekali.

## Alur & Fallback Chain

1. `RecognizeScreen` default menampilkan kamera live barcode scan (package `mobile_scanner`).
2. Barcode terdeteksi → `ProductLookupService.lookupByBarcode(code)`:
   - Coba `GET https://world.openbeautyfacts.org/api/v2/product/{code}.json?fields=product_name,brands,ingredients_text` (kosmetik/skincare/personal care).
   - Kalau `status != 1` atau `ingredients_text` kosong, coba `GET https://world.openfoodfacts.org/api/v2/product/{code}.json?fields=product_name,brands,ingredients_text` (makanan/suplemen).
   - Kalau salah satu ketemu dengan `ingredients_text` tidak kosong → lanjut ke langkah 5.
   - Kalau keduanya tidak ketemu → tampilkan pilihan: **"Foto Kemasan"** atau **"Foto Komposisi Manual"** (ke `/scan`).
3. User pilih "Foto Kemasan" → ambil foto (kamera/galeri, pola sama seperti `ScanBloc` pakai `image_picker`) → `GeminiService.identifyPackaging(imageFile)`: panggilan vision-only (tanpa search tool) yang mengembalikan `{ product_name, brand, category, confidence }` dalam JSON (`responseMimeType: application/json`, sama seperti `analyzeIngredients` yang sudah ada).
4. Kalau `confidence` adalah `"high"` atau `"medium"` (bukan `"low"`) dan `product_name` tidak kosong → `GeminiService.searchCompositionByWeb(productName, brand)`: panggilan text-only **dengan** tool `google_search` (tanpa `responseMimeType` json — grounding dan strict-JSON tidak dicampur dalam satu call untuk mengurangi risiko error format). Prompt minta Gemini balas HANYA teks daftar bahan mentah, atau persis string `TIDAK_DITEMUKAN` kalau tidak ada sumber terpercaya.
   - Response mengandung `TIDAK_DITEMUKAN` (persis, dicek via helper `isCompositionNotFound(String text)`) atau request gagal/error apa pun (termasuk kalau tool `google_search` ternyata tidak didukung di tier ini) → treated sama seperti "tidak ketemu": tampilkan pilihan "Foto Komposisi Manual".
   - Ketemu teks komposisi → lanjut langkah 5.
5. `GeminiService.analyzeIngredientsFromText(ingredientsText, resultId, productNameHint)` → prompt sama seperti `_buildAnalysisPrompt()` yang sudah ada, tapi menerima teks komposisi sebagai bagian `text` di `contents.parts` (bukan `inline_data` gambar) → hasil `AnalysisResult` sama struktur.
6. `RecognizeBloc` simpan hasil via `storageService.saveToHistory(result)` (persis pola `ScanBloc`) → emit `RecognizeSuccess(result)` → `RecognizeScreen` navigasi `context.pushReplacement('/result/${result.id}')`.

`imagePath` pada `AnalysisResult` untuk jalur barcode-only akan `null` (tidak ada foto yang diambil). Ini aman — `imagePath` sudah nullable di model, dan tidak ada satu pun layar (`ResultScreen`, `HistoryPreviewCard`, dll) yang benar-benar merender gambar dari field ini saat ini, jadi tidak ada guard tambahan yang diperlukan. Untuk jalur foto-kemasan, foto kemasan itu sendiri dipakai sebagai `imagePath`.

## Komponen Baru

### `lib/services/product_lookup_service.dart`
- Class `ProductLookupResult { productName, brand, ingredientsText }` (bukan model global — hanya dipakai internal fitur ini).
- `class ProductLookupService { Future<ProductLookupResult?> lookupByBarcode(String barcode) }` — return `null` kalau tidak ketemu di kedua database. Melempar exception khusus (`ProductLookupException`) hanya untuk error jaringan (bukan untuk "tidak ketemu", yang direpresentasikan sebagai `null`).

### `lib/services/gemini_service.dart` (extend, bukan file baru)
- Refactor: `_parseResponse`/`_buildAnalysisPrompt`/`_parseCategory`/`_parseSafetyLevel` sudah reusable (private static-ish), dipakai ulang oleh method baru.
- `Future<AnalysisResult> analyzeIngredientsFromText({required String ingredientsText, required String resultId, String? productNameHint})` — kirim `contents.parts` berisi satu `text` part (prompt analisis + teks komposisi + hint nama produk kalau ada), `responseMimeType: application/json`, parsing pakai `_parseResponse` dengan `imagePath: null`.
- `Future<PackagingIdentification> identifyPackaging({required File imageFile})` — vision-only, JSON `{product_name, brand, category, confidence}` (`confidence` salah satu dari string `"high"`, `"medium"`, `"low"`), `responseMimeType: application/json`. `PackagingIdentification` adalah class sederhana (pola sama `ProductLookupResult`): `{ String? productName, String? brand, ProductCategory category, String confidence }`.
- `Future<String?> searchCompositionByWeb({required String productName, String? brand})` — text-only, `tools: [{"google_search": {}}]`, TANPA `responseMimeType` (biar tidak konflik dengan grounding). Return `null` kalau response mengandung sentinel `TIDAK_DITEMUKAN` (dicek via helper `isCompositionNotFound`) atau request gagal.

### `lib/features/recognize/`
- `recognize_event.dart`: `BarcodeDetected(String code)`, `PackagingPhotoCaptured(File image)` — pola identik `ScanEvent` (plain class, tanpa equatable, konsisten dengan `scan_event.dart` yang sudah ada).
- `recognize_state.dart`: `RecognizeInitial`, `RecognizeLookingUp`, `RecognizeIdentifying`, `RecognizeSearchingComposition(String productName)`, `RecognizeAnalyzing`, `RecognizeSuccess(AnalysisResult result)`, `RecognizeNotFound`, `RecognizeError(String message)`.
- `recognize_bloc.dart`: `RecognizeBloc extends Bloc<RecognizeEvent, RecognizeState>` — pola identik `ScanBloc`, pakai `storageService.getApiKey()`, `ProductLookupService`, `GeminiService`, `storageService.saveToHistory()`.
- `recognize_screen.dart`: `MobileScanner` widget dari package `mobile_scanner` sebagai default view, tombol "Foto Kemasan" (image_picker, pola sama `ScanScreen`), tombol "Foto Komposisi Manual" (`context.push('/scan')` langsung, tanpa lewat bloc), `BlocListener` navigasi ke `/result/:id` saat `RecognizeSuccess`.

### Router & Home
- `app_router.dart`: tambah `GoRoute('/recognize', ...)` dengan `BlocProvider<RecognizeBloc>` (pola identik route `/scan`).
- `home_screen.dart`: ubah satu baris di `_pushScan()` — target `'/scan'` → `'/recognize'` (dipakai FAB & chip kategori, sudah disatukan lewat helper ini dari sesi sebelumnya).

### Dependency Baru
- `mobile_scanner` (pubspec.yaml) — package Flutter untuk live barcode scanning, tidak reinvent OCR barcode sendiri.

## Error Handling

- Error jaringan di `ProductLookupService` (timeout, no internet) → `RecognizeError` dengan pesan generik, tombol retry balik ke barcode scan.
- Error dari `GeminiService` (termasuk kalau `google_search` tool ditolak API) di kedua method baru → ditangkap sebagai `GeminiException` yang sudah ada, diperlakukan sama seperti "tidak ketemu" → `RecognizeNotFound` → user diarahkan ke fallback, bukan dead-end.

## Batasan yang Disadari (bukan bug, tidak perlu di-fix di iterasi ini)

- Obat-obatan/suplemen kemungkinan besar tidak ada di Open Food/Beauty Facts (database itu fokus makanan & kosmetik) — untuk kategori ini jalur barcode kemungkinan besar selalu jatuh ke fallback. Ini realistis, bukan bug.
- Ketersediaan tool `google_search` di tier API key ini belum divalidasi sampai benar-benar dicoba di implementasi — sudah dimitigasi lewat fallback otomatis di atas.
- Pencocokan nama produk via web search tetap best-effort teks (sama kelas batasan dengan matching alergi/compare yang sudah ada), bukan verifikasi resmi ke database farmasi/BPOM.

## Testing

- `test/product_lookup_service_test.dart`: mock `http.Client` (pakai package `http`'s testable client atau `mockito`/manual fake), test `lookupByBarcode` untuk 3 skenario: ketemu di Open Beauty Facts, ketemu di Open Food Facts (setelah OBF gagal), tidak ketemu di keduanya (return `null`).
- `test/gemini_service_composition_test.dart`: unit test helper murni `isCompositionNotFound(String text)` — tidak perlu mock HTTP untuk ini karena logic-nya cuma pengecekan string sentinel.
- Verifikasi manual di device (pola sama seperti sesi-sesi sebelumnya): coba scan barcode produk kosmetik ber-barcode dulu (jalur paling mungkin berhasil), lalu coba jalur foto-kemasan untuk produk yang barcode-nya tidak ketemu.

## Di Luar Cakupan (YAGNI)

- Tidak ada input teks manual "cari nama produk" tanpa foto/barcode.
- Tidak ada OCR angka barcode dari foto biasa (pakai `mobile_scanner` langsung, bukan reinvent).
- Tidak menyimpan confidence/sumber data (barcode vs web search vs manual) sebagai field baru di `AnalysisResult` — cukup hasil akhir yang sama strukturnya seperti sekarang.
- Tidak ada perubahan apa pun ke `ScanBloc`/`scan_screen.dart`/`scan_event.dart`/`scan_state.dart`.
