// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:servicehponline/features/admin/pages/admin_dashboard_page.dart';

/// File ini hanya untuk kompatibilitas dengan kode lama
/// Penggunaan sekarang:
/// import 'package:servicehponline/features/admin/pages/admin_dashboard_page.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const AdminDashboardPage();
  }
}
