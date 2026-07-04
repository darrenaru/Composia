# Composia — Setup & Panduan Penggunaan

## Prasyarat

1. **Flutter SDK** (v3.16+)
   - Download: https://docs.flutter.dev/get-started/install/windows
   - Tambahkan `flutter/bin` ke PATH

2. **Android Studio** atau **VS Code** dengan ekstensi Flutter

3. **API Key Gemini**
   - Daftar di: https://aistudio.google.com/apikey
   - Buat API Key baru

## Instalasi

```bash
# 1. Masuk ke direktori proyek
cd C:\Composia

# 2. Install dependencies
flutter pub get

# 3. Periksa setup Flutter
flutter doctor

# 4. Jalankan di emulator/perangkat (key wajib disertakan via --dart-define)
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

## Struktur Proyek

```
lib/
├── main.dart                    # Entry point
├── app.dart                     # Root widget + routing
├── core/
│   ├── constants/               # Warna, string, tipografi
│   ├── theme/                   # Material theme
│   ├── utils/                   # Utilitas gambar
│   └── widgets/                 # Widget yang dapat digunakan ulang
├── features/
│   ├── splash/                  # Layar splash
│   ├── onboarding/              # Onboarding 3 langkah
│   ├── home/                    # Beranda dengan riwayat
│   ├── scan/                    # Fitur scan (BLoC)
│   ├── result/                  # Hasil analisis ingredient
│   ├── history/                 # Riwayat scan
│   └── settings/                # Pengaturan API Key
├── models/
│   ├── ingredient.dart          # Model bahan + safety level
│   └── analysis_result.dart     # Hasil analisis produk
├── services/
│   ├── gemini_service.dart      # Integrasi Gemini API
│   └── storage_service.dart     # Penyimpanan lokal (SharedPreferences)
└── router/
    └── app_router.dart          # GoRouter navigation
```

## Fitur Utama

| Fitur | Deskripsi |
|-------|-----------|
| Scan Produk | Foto label produk via kamera atau galeri |
| AI Analysis | Claude AI menganalisis setiap bahan |
| Safety Rating | 4 level keamanan: Aman, Hati-hati, Peringatan, Berbahaya |
| Riwayat | Simpan dan lihat hasil scan sebelumnya |
| Filter Bahan | Filter berdasarkan level keamanan |
| Deteksi Alergen | Identifikasi bahan alergen umum |
| Rekomendasi | Saran penggunaan dari AI |

## Kategori Produk yang Didukung

- 💊 Obat-obatan (Medicine)
- 💄 Kosmetik (Cosmetics)
- 🌿 Skincare
- 👶 Produk Bayi (Baby Products)
- 💪 Suplemen (Health Supplements)
- 🧴 Perawatan Diri (Personal Care)

## Konfigurasi API Key

Key Gemini ditanam saat build lewat `--dart-define`, bukan diketik manual di
aplikasi (tidak ada UI untuk itu). Simpan key kamu di password manager atau
file lokal yang **tidak** ditrack git (jangan pernah taruh literal key di
kode/commit — GitHub akan menolak push yang mengandung secret).

## Build Release

```bash
# Android APK — untuk dibagikan ke teman
flutter build apk --release --dart-define=GEMINI_API_KEY=your_key_here

# Android App Bundle (untuk Play Store)
flutter build appbundle --release --dart-define=GEMINI_API_KEY=your_key_here

# iOS (hanya di macOS)
flutter build ios --release --dart-define=GEMINI_API_KEY=your_key_here
```

## Troubleshooting

**Flutter tidak ditemukan:**
```bash
# Tambahkan ke PATH (Windows)
$env:PATH += ";C:\flutter\bin"
```

**Error `flutter pub get`:**
```bash
flutter clean
flutter pub get
```

**Kamera tidak berfungsi di emulator:**
Gunakan perangkat fisik untuk fitur kamera.
