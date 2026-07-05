class AppStrings {
  AppStrings._();

  static const String appName = 'Composia';
  static const String appTagline = 'Kenali Setiap Bahan dengan Cerdas';

  // Onboarding
  static const String onboarding1Title = 'Scan Label Produk';
  static const String onboarding1Desc =
      'Foto label produk apapun — obat, kosmetik, skincare, makanan, minuman, hingga produk rumah tangga.';
  static const String onboarding2Title = 'AI Analisis Bahan';
  static const String onboarding2Desc =
      'Kecerdasan buatan kami menganalisis setiap bahan dan menjelaskan fungsinya.';
  static const String onboarding3Title = 'Pahami dengan Mudah';
  static const String onboarding3Desc =
      'Dapatkan penjelasan sederhana, rating keamanan, dan rekomendasi yang personal.';

  // Bottom nav
  static const String navHomeLabel = 'Home';
  static const String navSearchLabel = 'Cari';
  static const String navHistoryLabel = 'Riwayat';
  static const String navSettingsLabel = 'Pengaturan';

  // Home
  static const String homeGreeting = 'Halo!';
  static const String homeSubGreeting = 'Produk apa yang ingin kamu periksa?';
  static const String scanButton = 'Scan Produk';
  static const String recentScans = 'Scan Terbaru';
  static const String noHistory = 'Belum ada riwayat scan';
  static const String noHistoryDesc = 'Scan produk pertamamu sekarang!';

  // Scan
  static const String scanTitle = 'Scan Produk';
  static const String takePicture = 'Ambil Foto';
  static const String chooseGallery = 'Pilih dari Galeri';
  static const String analyzeButton = 'Analisis Bahan';
  static const String scanInstruction =
      'Arahkan kamera ke label bahan produk atau pilih foto dari galeri';
  static const String imageSelected = 'Foto berhasil dipilih';

  // Analysis
  static const String analyzing = 'Menganalisis bahan...';
  static const String analyzingDesc =
      'AI sedang membaca dan menganalisis setiap bahan pada produkmu';
  static const String analysisComplete = 'Analisis Selesai';

  // Result
  static const String resultTitle = 'Hasil Analisis';
  static const String ingredients = 'Daftar Bahan';
  static const String safeIngredients = 'Aman';
  static const String cautionIngredients = 'Perlu Perhatian';
  static const String warningIngredients = 'Peringatan';
  static const String dangerIngredients = 'Berbahaya';
  static const String unknownIngredients = 'Tidak Diketahui';
  static const String overallSafety = 'Keamanan Keseluruhan';
  static const String productType = 'Jenis Produk';
  static const String productName = 'Nama Produk';
  static const String summary = 'Ringkasan';
  static const String readMore = 'Selengkapnya';
  static const String saveResult = 'Simpan Hasil';
  static const String shareResult = 'Bagikan';

  // History
  static const String historyTitle = 'Riwayat Scan';
  static const String deleteHistory = 'Hapus';
  static const String clearAll = 'Hapus Semua';

  // Settings
  static const String settingsTitle = 'Pengaturan';
  static const String language = 'Bahasa';
  static const String notifications = 'Notifikasi';
  static const String about = 'Tentang Composia';
  static const String version = 'Versi';
  static const String privacyPolicy = 'Kebijakan Privasi';
  static const String termsOfService = 'Syarat & Ketentuan';

  // Safety Labels
  static const String safeLabel = 'Aman';
  static const String cautionLabel = 'Hati-hati';
  static const String warningLabel = 'Peringatan';
  static const String dangerLabel = 'Berbahaya';
  static const String unknownLabel = 'Tidak Diketahui';

  // Errors
  static const String errorGeneral = 'Terjadi kesalahan. Coba lagi.';
  static const String errorNetwork = 'Tidak ada koneksi internet.';
  static const String errorApiKey = 'API Key tidak valid atau belum diatur.';
  static const String errorImageProcess = 'Gagal memproses gambar.';
  static const String errorNoIngredients =
      'Tidak ditemukan daftar bahan pada gambar ini.';
  static const String retryButton = 'Coba Lagi';

  // Categories
  static const String categoryMedicine = 'Obat-obatan';
  static const String categoryCosmetics = 'Kosmetik';
  static const String categorySkincare = 'Skincare';
  static const String categoryBabyProduct = 'Produk Bayi';
  static const String categorySupplement = 'Suplemen';
  static const String categoryPersonalCare = 'Perawatan Diri';
  static const String categoryFoodBeverage = 'Makanan & Minuman';
  static const String categoryHousehold = 'Produk Rumah Tangga';
  static const String categoryGeneral = 'Produk Umum';
}
