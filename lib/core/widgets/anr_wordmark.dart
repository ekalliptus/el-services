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

/// Loader bermerek: wordmark ANRServices + indikator progres halus.
/// Dipakai untuk splash/loading antar-halaman agar konsisten.
class AnrBrandLoader extends StatelessWidget {
  const AnrBrandLoader({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AnrWordmark(fontSize: 30),
        const SizedBox(height: 24),
        SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation(scheme.primary),
          ),
        ),
      ],
    );
  }
}
