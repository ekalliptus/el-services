import 'package:flutter/material.dart';

/// Design tokens untuk Admin Dashboard
///
/// Kelas ini berisi konstanta desain yang digunakan di seluruh
/// aplikasi admin untuk memastikan konsistensi visual.
class AdminDesignTokens {
  // Spacing Tokens (dalam pixel)
  static const double spacingXxs = 4.0;
  static const double spacingXs = 8.0;
  static const double spacingSm = 12.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacingXxl = 48.0;
  static const double spacingHuge = 64.0;

  // Radius Tokens (dalam pixel)
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusPill = 500.0;

  // Elevation Tokens (dalam pixel)
  static const double elevationXs = 1.0;
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;

  // Opacity Tokens
  static const double opacityDisabled = 0.5;
  static const double opacityScrim = 0.6;
  static const double opacityHover = 0.08;
  static const double opacityFocus = 0.12;
  static const double opacityPressed = 0.16;
  static const double opacityDrag = 0.08;

  // Duration Tokens (dalam milliseconds)
  static const double durationXs = 100.0;
  static const double durationSm = 200.0;
  static const double durationMd = 300.0;
  static const double durationLg = 400.0;
  static const double durationXl = 500.0;

  // Border Width Tokens (dalam pixel)
  static const double borderWidthXs = 1.0;
  static const double borderWidthSm = 2.0;
  static const double borderWidthMd = 3.0;
  static const double borderWidthLg = 4.0;

  // Font Size Tokens (dalam pixel)
  static const double fontSizeXxs = 11.0;
  static const double fontSizeXs = 12.0;
  static const double fontSizeSm = 14.0;
  static const double fontSizeMd = 16.0;
  static const double fontSizeLg = 20.0;
  static const double fontSizeXl = 24.0;
  static const double fontSizeXxl = 32.0;

  // Font Weight Tokens
  static const FontWeight fontWeightLight = FontWeight.w300;
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  // Icon Size Tokens (dalam pixel)
  static const double iconSizeXs = 16.0;
  static const double iconSizeSm = 20.0;
  static const double iconSizeMd = 24.0;
  static const double iconSizeLg = 32.0;
  static const double iconSizeXl = 48.0;

  // Widget-widget untuk memberikan spasi konsisten
  static const Widget horizontalSpacerXxs = SizedBox(width: spacingXxs);
  static const Widget horizontalSpacerXs = SizedBox(width: spacingXs);
  static const Widget horizontalSpacerSm = SizedBox(width: spacingSm);
  static const Widget horizontalSpacerMd = SizedBox(width: spacingMd);
  static const Widget horizontalSpacerLg = SizedBox(width: spacingLg);
  static const Widget horizontalSpacerXl = SizedBox(width: spacingXl);
  static const Widget horizontalSpacerXxl = SizedBox(width: spacingXxl);

  static const Widget verticalSpacerXxs = SizedBox(height: spacingXxs);
  static const Widget verticalSpacerXs = SizedBox(height: spacingXs);
  static const Widget verticalSpacerSm = SizedBox(height: spacingSm);
  static const Widget verticalSpacerMd = SizedBox(height: spacingMd);
  static const Widget verticalSpacerLg = SizedBox(height: spacingLg);
  static const Widget verticalSpacerXl = SizedBox(height: spacingXl);
  static const Widget verticalSpacerXxl = SizedBox(height: spacingXxl);
}
