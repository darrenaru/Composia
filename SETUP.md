# Composia — Setup & Panduan Penggunaan

## Prasyarat

1. **Flutter SDK** (v3.16+)
   - Download: https://docs.flutter.dev/get-started/install/windows
   - Tambahkan `flutter/bin` ke PATH

2. **Android Studio** atau **VS Code** dengan ekstensi Flutter

3. **API Key Anthropic (Claude)**
   - Daftar di: https://console.anthropic.com
   - Buat API Key baru
   - Format: `sk-ant-api03-...`

## Instalasi

```bash
# 1. Masuk ke direktori proyek
cd C:\Composia

# 2. Install dependencies
flutter pub get

# 3. Periksa setup Flutter
flutter doctor

# 4. Jalankan di emulator/perangkat
flutter run
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
│   ├── claude_service.dart      # Integrasi Claude API
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

1. Buka aplikasi → Pengaturan (ikon gear di sudut kanan atas)
2. Masukkan API Key Anthropic kamu
3. Tekan "Simpan API Key"
4. Selesai! Kamu siap menganalisis produk.

## Build Release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (untuk Play Store)
flutter build appbundle --release

# iOS (hanya di macOS)
flutter build ios --release
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
