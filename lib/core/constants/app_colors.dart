import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors — "Botanical Calm"
  static const Color primary = Color(0xFFC97C5D); // clay/terracotta
  static const Color primaryLight = Color(0xFFE2AC94);
  static const Color accent = Color(0xFF6B8F71); // sage
  static const Color accentLight = Color(0xFFB9CDB9);

  // Background
  static const Color background = Color(0xFFFBF8F3); // warm cream
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Safety Levels (makna semantik tetap: hijau/kuning/oranye/merah/abu)
  static const Color safeGreen = Color(0xFF4C956C);
  static const Color safeGreenLight = Color(0xFFE1EFE2);
  static const Color cautionYellow = Color(0xFFF2A65A);
  static const Color cautionYellowLight = Color(0xFFFCEBD2);
  static const Color warningOrange = Color(0xFFE8871E);
  static const Color warningOrangeLight = Color(0xFFF8DCC0);
  static const Color dangerRed = Color(0xFFC1272D);
  static const Color dangerRedLight = Color(0xFFF6DADA);
  static const Color unknownGrey = Color(0xFF9C9490);
  static const Color unknownGreyLight = Color(0xFFECEAE8);

  // Text
  static const Color textPrimary = Color(0xFF2B2320);
  static const Color textSecondary = Color(0xFF6E645C);
  static const Color textHint = Color(0xFFA79C92);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Divider & Border
  static const Color divider = Color(0xFFE8E0D6);
  static const Color border = Color(0xFFEDE3D6);

  // Kategori produk
  static const Color categorySkincare = Color(0xFF7D8B4A); // olive/moss
  static const Color categoryCosmetics = Color(0xFFC97A94); // dusty rose
  static const Color categoryBabyProduct = Color(0xFFA78BBE); // soft lavender
  static const Color categorySupplement = Color(0xFF5B8A9A); // dusty teal-blue
  static const Color categoryPersonalCare = Color(0xFFA98B5D); // warm ochre

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC97C5D), Color(0xFFE0A07E)],
  );
}
