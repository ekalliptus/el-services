import 'package:flutter/material.dart';

class StatusUtils {
  /// Mendapatkan teks tampilan untuk status
  static String getStatusText(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu Admin';
      case 'WAITING_PAYMENT':
        return 'Belum Dibayar';
      case 'PROCESSED':
        return 'Diproses';
      case 'COMPLETED':
        return 'Selesai';
      case 'COMPLAINED':
        return 'Komplain';
      case 'EXPIRED':
        return 'Kadaluarsa';
      default:
        return status;
    }
  }

  /// Mendapatkan warna untuk status
  static Color getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'WAITING_PAYMENT':
        return Colors.orange;
      case 'PROCESSED':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'COMPLAINED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
