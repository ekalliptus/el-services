import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Tema ANRServices — light (ivory) & dark (matte charcoal).
/// Definisi tema terpusat; menggantikan ThemeData inline di main.dart.
class AppTheme {
  AppTheme._();

  static const _radius = 16.0;

  static ThemeData get light => _build(
        brightness: Brightness.light,
        scheme: const ColorScheme(
          brightness: Brightness.light,
          primary: AppColors.lightPrimary,
          onPrimary: AppColors.lightOnPrimary,
          primaryContainer: AppColors.lightSurfaceAlt,
          onPrimaryContainer: AppColors.lightTextPrimary,
          secondary: AppColors.lightAccent,
          onSecondary: AppColors.lightOnPrimary,
          secondaryContainer: AppColors.lightSurfaceAlt,
          onSecondaryContainer: AppColors.lightTextPrimary,
          tertiary: AppColors.info,
          onTertiary: Colors.white,
          error: AppColors.lightError,
          onError: Colors.white,
          surface: AppColors.lightSurface,
          onSurface: AppColors.lightTextPrimary,
          surfaceContainerHighest: AppColors.lightSurfaceAlt,
          onSurfaceVariant: AppColors.lightTextSecondary,
          outline: AppColors.lightOutline,
          outlineVariant: AppColors.lightOutline,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: AppColors.darkSurface,
          onInverseSurface: AppColors.darkTextPrimary,
          inversePrimary: AppColors.darkPrimary,
        ),
        background: AppColors.lightBackground,
        textColor: AppColors.lightTextPrimary,
        secondaryText: AppColors.lightTextSecondary,
      );

  static ThemeData get dark => _build(
        brightness: Brightness.dark,
        scheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: AppColors.darkPrimary,
          onPrimary: AppColors.darkOnPrimary,
          primaryContainer: AppColors.darkSurfaceAlt,
          onPrimaryContainer: AppColors.darkTextPrimary,
          secondary: AppColors.darkAccent,
          onSecondary: AppColors.darkOnPrimary,
          secondaryContainer: AppColors.darkSurfaceAlt,
          onSecondaryContainer: AppColors.darkTextPrimary,
          tertiary: AppColors.info,
          onTertiary: Colors.white,
          error: AppColors.darkError,
          onError: AppColors.darkOnPrimary,
          surface: AppColors.darkSurface,
          onSurface: AppColors.darkTextPrimary,
          surfaceContainerHighest: AppColors.darkSurfaceAlt,
          onSurfaceVariant: AppColors.darkTextSecondary,
          outline: AppColors.darkOutline,
          outlineVariant: AppColors.darkOutline,
          shadow: Colors.black,
          scrim: Colors.black,
          inverseSurface: AppColors.lightSurface,
          onInverseSurface: AppColors.lightTextPrimary,
          inversePrimary: AppColors.lightPrimary,
        ),
        background: AppColors.darkBackground,
        textColor: AppColors.darkTextPrimary,
        secondaryText: AppColors.darkTextSecondary,
      );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color background,
    required Color textColor,
    required Color secondaryText,
  }) {
    final textTheme = GoogleFonts.poppinsTextTheme(
      ThemeData(brightness: brightness).textTheme,
    ).apply(bodyColor: textColor, displayColor: textColor);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 60,
        iconTheme: IconThemeData(color: scheme.primary),
        titleTextStyle: GoogleFonts.poppins(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: BorderSide(color: scheme.outline),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          elevation: 0,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.outline),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_radius),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        labelStyle: TextStyle(color: secondaryText),
        hintStyle: TextStyle(color: secondaryText),
        prefixIconColor: secondaryText,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_radius),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        labelStyle: GoogleFonts.poppins(color: textColor),
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
