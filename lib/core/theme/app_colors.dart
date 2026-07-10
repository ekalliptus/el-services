import 'package:flutter/material.dart';

/// Palet warna ANRServices — Ivory + Matte Charcoal.
/// Satu-satunya sumber kebenaran warna. Jangan hardcode Color(0x..) di widget;
/// gunakan Theme.of(context).colorScheme.* atau token di sini.
class AppColors {
  AppColors._();

  // ---- Light (ivory) ----
  static const lightBackground = Color(0xFFF5F1E8); // ivory
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFFAF7F0); // off-white card
  static const lightPrimary = Color(0xFF2B2B28); // matte charcoal (brand)
  static const lightOnPrimary = Color(0xFFF5F1E8);
  static const lightAccent = Color(0xFF8B8578); // warm taupe
  static const lightOutline = Color(0xFFE3DDCF);
  static const lightTextPrimary = Color(0xFF2B2B28);
  static const lightTextSecondary = Color(0xFF6E695E);
  static const lightError = Color(0xFFB23A2E); // matte brick

  // ---- Dark (matte) ----
  static const darkBackground = Color(0xFF1E1E1B);
  static const darkSurface = Color(0xFF2B2B28);
  static const darkSurfaceAlt = Color(0xFF33332F);
  static const darkPrimary = Color(0xFFF5F1E8); // ivory (brand on dark)
  static const darkOnPrimary = Color(0xFF1E1E1B);
  static const darkAccent = Color(0xFFA8A290);
  static const darkOutline = Color(0xFF3A3A36);
  static const darkTextPrimary = Color(0xFFF0EBDD);
  static const darkTextSecondary = Color(0xFFB5AF9F);
  static const darkError = Color(0xFFE08A7E);

  // Aksen status (netral utk light/dark).
  static const success = Color(0xFF5B7052); // matte olive
  static const warning = Color(0xFFB58A3E); // matte amber
  static const info = Color(0xFF4E6472); // matte slate
}
