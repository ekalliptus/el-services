import 'package:flutter/material.dart';
import 'package:servicehponline/core/theme/app_colors.dart';

/// DEPRECATED: gunakan Theme.of(context).colorScheme.* atau AppColors.
/// Dipertahankan sebagai alias agar pemakaian lama tidak pecah sekaligus.
class Constants {
  static const Color primaryColor = AppColors.lightPrimary;
}
