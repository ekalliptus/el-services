import 'package:flutter/material.dart';
import 'admin_design_tokens.dart';

/// Tema khusus untuk Dashboard Admin
///
/// Kelas ini menyediakan tema konsisten untuk seluruh dashboard admin,
/// termasuk skema warna, tipografi, bayangan, dan utilitas tema lainnya.
class AdminTheme {
  /// Mendapatkan tema terang untuk Dashboard Admin
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _lightColorScheme,
      textTheme: _buildTextTheme(),
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      inputDecorationTheme: _inputDecorationTheme,
      appBarTheme: _appBarTheme,
      cardTheme: _cardTheme,
      scaffoldBackgroundColor: _lightColorScheme.surface,
      dividerTheme: _dividerTheme,
    );
  }

  /// Mendapatkan tema gelap untuk Dashboard Admin
  static ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: _darkColorScheme,
      textTheme: _buildTextTheme(isDark: true),
      elevatedButtonTheme: _elevatedButtonThemeDark,
      outlinedButtonTheme: _outlinedButtonThemeDark,
      inputDecorationTheme: _inputDecorationThemeDark,
      appBarTheme: _appBarThemeDark,
      cardTheme: _cardThemeDark,
      scaffoldBackgroundColor: _darkColorScheme.surface,
      dividerTheme: _dividerTheme,
    );
  }

  /// Warna-warna kustom untuk tema terang
  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0061A4),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD1E4FF),
    onPrimaryContainer: Color(0xFF001D36),
    secondary: Color(0xFF535F70),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD7E3F7),
    onSecondaryContainer: Color(0xFF101C2B),
    tertiary: Color(0xFF6B5778),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFF2DAFF),
    onTertiaryContainer: Color(0xFF251431),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Color(0xFFF8FDFF),
    onSurface: Color(0xFF001F25),
    surfaceContainerHighest: Color(0xFFDFE2EB),
    onSurfaceVariant: Color(0xFF42474E),
    outline: Color(0xFF73777F),
    outlineVariant: Color(0xFFC3C7CF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFF00363F),
    onInverseSurface: Color(0xFFD6F6FF),
    inversePrimary: Color(0xFF9ECAFF),
    surfaceTint: Color(0xFF0061A4),
  );

  /// Warna-warna kustom untuk tema gelap
  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF9ECAFF),
    onPrimary: Color(0xFF003258),
    primaryContainer: Color(0xFF00497D),
    onPrimaryContainer: Color(0xFFD1E4FF),
    secondary: Color(0xFFBBC7DB),
    onSecondary: Color(0xFF253140),
    secondaryContainer: Color(0xFF3B4858),
    onSecondaryContainer: Color(0xFFD7E3F7),
    tertiary: Color(0xFFD6BEE4),
    onTertiary: Color(0xFF3B2948),
    tertiaryContainer: Color(0xFF523F5F),
    onTertiaryContainer: Color(0xFFF2DAFF),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFB4AB),
    surface: Color(0xFF001F25),
    onSurface: Color(0xFFA6EEFF),
    surfaceContainerHighest: Color(0xFF42474E),
    onSurfaceVariant: Color(0xFFC3C7CF),
    outline: Color(0xFF8D9199),
    outlineVariant: Color(0xFF42474E),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFA6EEFF),
    onInverseSurface: Color(0xFF001F25),
    inversePrimary: Color(0xFF0061A4),
    surfaceTint: Color(0xFF9ECAFF),
  );

  /// Membangun tema teks sesuai dengan design tokens
  static TextTheme _buildTextTheme({bool isDark = false}) {
    final Color textColor = isDark ? Colors.white : Colors.black;

    return TextTheme(
      displayLarge: TextStyle(
        fontSize: AdminDesignTokens.fontSizeXxl,
        fontWeight: AdminDesignTokens.fontWeightBold,
        color: textColor,
      ),
      displayMedium: TextStyle(
        fontSize: AdminDesignTokens.fontSizeXl,
        fontWeight: AdminDesignTokens.fontWeightBold,
        color: textColor,
      ),
      displaySmall: TextStyle(
        fontSize: AdminDesignTokens.fontSizeLg,
        fontWeight: AdminDesignTokens.fontWeightBold,
        color: textColor,
      ),
      headlineLarge: TextStyle(
        fontSize: AdminDesignTokens.fontSizeLg,
        fontWeight: AdminDesignTokens.fontWeightSemiBold,
        color: textColor,
      ),
      headlineMedium: TextStyle(
        fontSize: AdminDesignTokens.fontSizeMd,
        fontWeight: AdminDesignTokens.fontWeightSemiBold,
        color: textColor,
      ),
      headlineSmall: TextStyle(
        fontSize: AdminDesignTokens.fontSizeSm,
        fontWeight: AdminDesignTokens.fontWeightSemiBold,
        color: textColor,
      ),
      titleLarge: TextStyle(
        fontSize: AdminDesignTokens.fontSizeMd,
        fontWeight: AdminDesignTokens.fontWeightMedium,
        color: textColor,
      ),
      titleMedium: TextStyle(
        fontSize: AdminDesignTokens.fontSizeSm,
        fontWeight: AdminDesignTokens.fontWeightMedium,
        color: textColor,
      ),
      titleSmall: TextStyle(
        fontSize: AdminDesignTokens.fontSizeXs,
        fontWeight: AdminDesignTokens.fontWeightMedium,
        color: textColor,
      ),
      bodyLarge: TextStyle(
        fontSize: AdminDesignTokens.fontSizeSm,
        fontWeight: AdminDesignTokens.fontWeightRegular,
        color: textColor,
      ),
      bodyMedium: TextStyle(
        fontSize: AdminDesignTokens.fontSizeXs,
        fontWeight: AdminDesignTokens.fontWeightRegular,
        color: textColor,
      ),
      bodySmall: TextStyle(
        fontSize: AdminDesignTokens.fontSizeXxs,
        fontWeight: AdminDesignTokens.fontWeightRegular,
        color: textColor.withOpacity(0.8),
      ),
      labelLarge: TextStyle(
        fontSize: AdminDesignTokens.fontSizeXs,
        fontWeight: AdminDesignTokens.fontWeightMedium,
        color: textColor,
      ),
      labelMedium: TextStyle(
        fontSize: AdminDesignTokens.fontSizeXxs,
        fontWeight: AdminDesignTokens.fontWeightMedium,
        color: textColor,
      ),
      labelSmall: TextStyle(
        fontSize: AdminDesignTokens.fontSizeXxs,
        fontWeight: AdminDesignTokens.fontWeightRegular,
        color: textColor.withOpacity(0.7),
      ),
    );
  }

  /// Tema untuk tombol elevated
  static final ElevatedButtonThemeData _elevatedButtonTheme =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: AdminDesignTokens.spacingMd,
        vertical: AdminDesignTokens.spacingSm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDesignTokens.radiusMd),
      ),
      elevation: AdminDesignTokens.elevationSm,
    ),
  );

  /// Tema untuk tombol elevated pada tema gelap
  static final ElevatedButtonThemeData _elevatedButtonThemeDark =
      ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: AdminDesignTokens.spacingMd,
        vertical: AdminDesignTokens.spacingSm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDesignTokens.radiusMd),
      ),
      elevation: AdminDesignTokens.elevationSm,
    ),
  );

  /// Tema untuk tombol outlined
  static final OutlinedButtonThemeData _outlinedButtonTheme =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: AdminDesignTokens.spacingMd,
        vertical: AdminDesignTokens.spacingSm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDesignTokens.radiusMd),
      ),
      side: BorderSide(
        width: AdminDesignTokens.borderWidthMd,
        color: _lightColorScheme.primary,
      ),
    ),
  );

  /// Tema untuk tombol outlined pada tema gelap
  static final OutlinedButtonThemeData _outlinedButtonThemeDark =
      OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        horizontal: AdminDesignTokens.spacingMd,
        vertical: AdminDesignTokens.spacingSm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminDesignTokens.radiusMd),
      ),
      side: BorderSide(
        width: AdminDesignTokens.borderWidthMd,
        color: _darkColorScheme.primary,
      ),
    ),
  );

  /// Tema untuk dekorasi input
  static final InputDecorationTheme _inputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: _lightColorScheme.surface,
    contentPadding: EdgeInsets.all(AdminDesignTokens.spacingSm),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
      borderSide: BorderSide(
        width: AdminDesignTokens.borderWidthSm,
        color: _lightColorScheme.outline,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
      borderSide: BorderSide(
        width: AdminDesignTokens.borderWidthSm,
        color: _lightColorScheme.outline,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
      borderSide: BorderSide(
        width: AdminDesignTokens.borderWidthMd,
        color: _lightColorScheme.primary,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
      borderSide: BorderSide(
        width: AdminDesignTokens.borderWidthSm,
        color: _lightColorScheme.error,
      ),
    ),
  );

  /// Tema untuk dekorasi input pada tema gelap
  static final InputDecorationTheme _inputDecorationThemeDark =
      InputDecorationTheme(
    filled: true,
    fillColor: _darkColorScheme.surfaceContainerHighest,
    contentPadding: EdgeInsets.all(AdminDesignTokens.spacingSm),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
      borderSide: BorderSide(
        width: AdminDesignTokens.borderWidthSm,
        color: _darkColorScheme.outline,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
      borderSide: BorderSide(
        width: AdminDesignTokens.borderWidthSm,
        color: _darkColorScheme.outline,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
      borderSide: BorderSide(
        width: AdminDesignTokens.borderWidthMd,
        color: _darkColorScheme.primary,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusSm),
      borderSide: BorderSide(
        width: AdminDesignTokens.borderWidthSm,
        color: _darkColorScheme.error,
      ),
    ),
  );

  /// Tema untuk AppBar
  static final AppBarTheme _appBarTheme = AppBarTheme(
    backgroundColor: _lightColorScheme.surface,
    foregroundColor: _lightColorScheme.onSurface,
    elevation: AdminDesignTokens.elevationSm,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: AdminDesignTokens.fontSizeMd,
      fontWeight: AdminDesignTokens.fontWeightSemiBold,
      color: _lightColorScheme.onSurface,
    ),
  );

  /// Tema untuk AppBar pada tema gelap
  static final AppBarTheme _appBarThemeDark = AppBarTheme(
    backgroundColor: _darkColorScheme.surface,
    foregroundColor: _darkColorScheme.onSurface,
    elevation: AdminDesignTokens.elevationSm,
    centerTitle: false,
    titleTextStyle: TextStyle(
      fontSize: AdminDesignTokens.fontSizeMd,
      fontWeight: AdminDesignTokens.fontWeightSemiBold,
      color: _darkColorScheme.onSurface,
    ),
  );

  /// Tema untuk Card
  static final CardTheme _cardTheme = CardTheme(
    color: _lightColorScheme.surface,
    elevation: AdminDesignTokens.elevationSm,
    margin: EdgeInsets.all(AdminDesignTokens.spacingSm),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusMd),
    ),
  );

  /// Tema untuk Card pada tema gelap
  static final CardTheme _cardThemeDark = CardTheme(
    color: _darkColorScheme.surfaceContainerHighest,
    elevation: AdminDesignTokens.elevationSm,
    margin: EdgeInsets.all(AdminDesignTokens.spacingSm),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AdminDesignTokens.radiusMd),
    ),
  );

  /// Tema untuk Divider
  static final DividerThemeData _dividerTheme = DividerThemeData(
    space: AdminDesignTokens.spacingMd,
    thickness: AdminDesignTokens.borderWidthXs,
    color: _lightColorScheme.outlineVariant,
  );

  /// Container dengan efek Neumorphic (desain soft-UI)
  static Widget neumorphicContainer({
    required Widget child,
    bool pressed = false,
    Color? backgroundColor,
    double radius = AdminDesignTokens.radiusMd,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16.0),
  }) {
    final Color bgColor = backgroundColor ?? _lightColorScheme.surface;

    // Warna bayangan untuk efek terang dan gelap
    final Color lightShadowColor =
        Colors.white.withOpacity(pressed ? 0.5 : 0.8);
    final Color darkShadowColor = Colors.black.withOpacity(pressed ? 0.2 : 0.1);

    // Offset untuk bayangan (berubah saat pressed)
    final Offset lightOffset = pressed ? Offset(1, 1) : Offset(-2, -2);
    final Offset darkOffset = pressed ? Offset(-1, -1) : Offset(2, 2);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          // Bayangan terang
          BoxShadow(
            color: lightShadowColor,
            offset: lightOffset,
            blurRadius: pressed ? 2 : 4,
            spreadRadius: pressed ? 1 : 0,
          ),
          // Bayangan gelap
          BoxShadow(
            color: darkShadowColor,
            offset: darkOffset,
            blurRadius: pressed ? 2 : 4,
            spreadRadius: pressed ? 1 : 0,
          ),
        ],
      ),
      child: child,
    );
  }

  /// Container yang merespon saat ditekan
  static Widget pressableContainer({
    required Widget child,
    required VoidCallback onPressed,
    bool pressed = false,
    Color? backgroundColor,
    double radius = AdminDesignTokens.radiusMd,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16.0),
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: Duration(milliseconds: AdminDesignTokens.durationSm.toInt()),
        curve: Curves.easeInOut,
        padding: padding,
        decoration: BoxDecoration(
          color: backgroundColor ?? _lightColorScheme.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(pressed ? 0.1 : 0.2),
              offset: pressed ? Offset(1, 1) : Offset(2, 2),
              blurRadius: pressed ? 2 : 4,
              spreadRadius: pressed ? 0 : 1,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
