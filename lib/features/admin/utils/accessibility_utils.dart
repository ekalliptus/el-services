import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/admin_design_tokens.dart';

/// Utilitas aksesibilitas untuk mempermudah implementasi fitur aksesibilitas
///
/// Kelas ini menyediakan metode dan komponen untuk memastikan
/// aplikasi admin memenuhi standar aksesibilitas WCAG 2.1 AA.
class AccessibilityUtils {
  /// Memeriksa apakah rasio kontras antara dua warna memenuhi standar WCAG
  ///
  /// Untuk teks normal: 4.5:1
  /// Untuk teks besar: 3:1
  static bool checkContrastRatio(Color foreground, Color background,
      {bool isLargeText = false}) {
    final double ratio = _calculateContrastRatio(foreground, background);
    return isLargeText ? ratio >= 3.0 : ratio >= 4.5;
  }

  /// Menghitung rasio kontras antara dua warna
  ///
  /// Formula sesuai dengan WCAG 2.1:
  /// (L1 + 0.05) / (L2 + 0.05) di mana L1 adalah luminance warna yang lebih terang
  /// dan L2 adalah luminance warna yang lebih gelap
  static double _calculateContrastRatio(Color color1, Color color2) {
    final double luminance1 = color1.computeLuminance();
    final double luminance2 = color2.computeLuminance();

    final double lighterLuminance =
        luminance1 > luminance2 ? luminance1 : luminance2;
    final double darkerLuminance =
        luminance1 > luminance2 ? luminance2 : luminance1;

    return (lighterLuminance + 0.05) / (darkerLuminance + 0.05);
  }

  /// Mendapatkan warna foreground yang aksesibel (hitam atau putih) berdasarkan warna background
  static Color getAccessibleForeground(Color background) {
    final double luminance = background.computeLuminance();
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  /// Widget yang menambahkan label semantik dan hint untuk screen reader
  static Widget semanticLabel({
    required Widget child,
    required String label,
    String? hint,
    bool excludeSemantics = false,
  }) {
    return Semantics(
      label: label,
      hint: hint,
      excludeSemantics: excludeSemantics,
      child: child,
    );
  }

  /// Widget yang mengatur fokus untuk navigasi keyboard
  static Widget focusable({
    required Widget child,
    required FocusNode focusNode,
    VoidCallback? onPressed,
  }) {
    return Focus(
      focusNode: focusNode,
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is RawKeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.space ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          if (onPressed != null) {
            onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

/// Widget yang memastikan area sentuh memiliki ukuran minimal yang aksesibel
class TouchTarget extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double minSize;

  /// Membuat area sentuh yang aksesibel dengan ukuran minimal (default 44px sesuai WCAG)
  const TouchTarget({
    Key? key,
    required this.child,
    this.onTap,
    this.minSize = 44.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: BoxConstraints(
          minWidth: minSize,
          minHeight: minSize,
        ),
        child: child,
      ),
    );
  }
}

/// Text dengan style yang aksesibel (memastikan ukuran font minimal)
class AccessibleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double minFontSize;

  /// Membuat teks yang memenuhi standar aksesibilitas dengan ukuran font minimal
  const AccessibleText(
    this.text, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.minFontSize = 12.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextStyle defaultStyle = Theme.of(context).textTheme.bodyMedium!;
    final TextStyle mergedStyle =
        style != null ? defaultStyle.merge(style) : defaultStyle;

    // Memastikan ukuran font minimal terpenuhi
    final double fontSize =
        mergedStyle.fontSize ?? defaultStyle.fontSize ?? 14.0;
    final TextStyle finalStyle = fontSize < minFontSize
        ? mergedStyle.copyWith(fontSize: minFontSize)
        : mergedStyle;

    return Text(
      text,
      style: finalStyle,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Tombol yang sepenuhnya aksesibel
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onPressed;
  final String semanticLabel;
  final String? semanticHint;
  final Color? backgroundColor;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Membuat tombol yang memenuhi standar aksesibilitas
  const AccessibleButton({
    Key? key,
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.semanticHint,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AdminDesignTokens.spacingMd,
      vertical: AdminDesignTokens.spacingSm,
    ),
    this.borderRadius = AdminDesignTokens.radiusSm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color bgColor = backgroundColor ?? theme.colorScheme.primary;
    final Color textColor = AccessibilityUtils.getAccessibleForeground(bgColor);

    return Semantics(
      label: semanticLabel,
      hint: semanticHint,
      button: true,
      child: TouchTarget(
        onTap: onPressed,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: DefaultTextStyle(
            style: TextStyle(color: textColor),
            child: child,
          ),
        ),
      ),
    );
  }
}
