import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'admin_design_tokens.dart';

/// Tema khusus untuk Dashboard Admin.
///
/// Diselaraskan ke palet ANRServices: getLightTheme/getDarkTheme kini
/// mendelegasikan ke [AppTheme] global (ivory + matte charcoal) agar dashboard
/// admin konsisten dengan seluruh aplikasi.
class AdminTheme {
  /// Mendapatkan tema terang untuk Dashboard Admin.
  static ThemeData getLightTheme() => AppTheme.light;

  /// Mendapatkan tema gelap untuk Dashboard Admin.
  static ThemeData getDarkTheme() => AppTheme.dark;

  /// Container dengan efek Neumorphic (desain soft-UI).
  static Widget neumorphicContainer({
    required Widget child,
    bool pressed = false,
    Color? backgroundColor,
    double radius = AdminDesignTokens.radiusMd,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16.0),
  }) {
    final Color bgColor = backgroundColor ?? AppColors.lightSurface;

    // Warna bayangan untuk efek terang dan gelap.
    final Color lightShadowColor =
        AppColors.lightSurface.withValues(alpha: pressed ? 0.5 : 0.8);
    final Color darkShadowColor =
        Colors.black.withValues(alpha: pressed ? 0.2 : 0.1);

    // Offset untuk bayangan (berubah saat pressed).
    final Offset lightOffset = pressed ? const Offset(1, 1) : const Offset(-2, -2);
    final Offset darkOffset = pressed ? const Offset(-1, -1) : const Offset(2, 2);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: lightShadowColor,
            offset: lightOffset,
            blurRadius: pressed ? 2 : 4,
            spreadRadius: pressed ? 1 : 0,
          ),
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

  /// Container yang merespon saat ditekan.
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
          color: backgroundColor ?? AppColors.lightSurface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: pressed ? 0.1 : 0.2),
              offset: pressed ? const Offset(1, 1) : const Offset(2, 2),
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
