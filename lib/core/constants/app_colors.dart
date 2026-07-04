import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Colors
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF9B8FF0);
  static const Color primaryDark = Color(0xFF4A3CC7);
  static const Color accent = Color(0xFFFF7675);
  static const Color accentLight = Color(0xFFFFB2B2);

  // Background
  static const Color background = Color(0xFFF8F7FF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1B4B);

  // Safety Levels
  static const Color safeGreen = Color(0xFF00B894);
  static const Color safeGreenLight = Color(0xFFDFFFF4);
  static const Color cautionYellow = Color(0xFFFDCB6E);
  static const Color cautionYellowLight = Color(0xFFFFF8E7);
  static const Color warningOrange = Color(0xFFE17055);
  static const Color warningOrangeLight = Color(0xFFFFF0EC);
  static const Color dangerRed = Color(0xFFD63031);
  static const Color dangerRedLight = Color(0xFFFFEBEB);
  static const Color unknownGrey = Color(0xFF636E72);
  static const Color unknownGreyLight = Color(0xFFF0F0F0);

  // Text
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color textHint = Color(0xFFB2BEC3);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Divider & Border
  static const Color divider = Color(0xFFDFE6E9);
  static const Color border = Color(0xFFEDEAFF);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C5CE7), Color(0xFF9B8FF0)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D3436), Color(0xFF1E1B4B)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFEDEAFF), Color(0xFFF8F7FF)],
  );
}
