import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wordmark teks ANRServices. "ANR" tebal warna brand, "Services" reguler
/// warna sekunder. Dipakai di onboarding, login, app bar, splash.
class AnrWordmark extends StatelessWidget {
  final double fontSize;
  final bool compact; // true: hanya "ANR" (mis. untuk ikon kecil)

  const AnrWordmark({super.key, this.fontSize = 26, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: fontSize,
          letterSpacing: -0.5,
        ),
        children: [
          TextSpan(
            text: 'ANR',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          if (!compact)
            TextSpan(
              text: 'Services',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
