import 'package:flutter/material.dart';

/// Model data untuk filter layanan di dashboard admin
class ServiceFilterModel {
  final String filterKey;
  final String displayName;
  final Color? selectedColor;
  final Color? textColor;

  ServiceFilterModel({
    required this.filterKey,
    required this.displayName,
    this.selectedColor,
    this.textColor,
  });

  /// Menghasilkan daftar filter yang tersedia
  static List<ServiceFilterModel> getFilterList() {
    return [
      ServiceFilterModel(
        filterKey: 'all',
        displayName: 'Semua',
      ),
      ServiceFilterModel(
        filterKey: 'pending',
        displayName: 'Menunggu Admin',
        selectedColor: Colors.blue[100],
        textColor: Colors.blue,
      ),
      ServiceFilterModel(
        filterKey: 'unpaid',
        displayName: 'Belum Dibayar',
        selectedColor: Colors.orange[100],
        textColor: Colors.orange,
      ),
      ServiceFilterModel(
        filterKey: 'processed',
        displayName: 'Diproses',
        selectedColor: Colors.blue[100],
        textColor: Colors.blue,
      ),
      ServiceFilterModel(
        filterKey: 'completed',
        displayName: 'Selesai',
        selectedColor: Colors.green[100],
        textColor: Colors.green,
      ),
      ServiceFilterModel(
        filterKey: 'complained',
        displayName: 'Komplain',
        selectedColor: Colors.red[100],
        textColor: Colors.red,
      ),
    ];
  }
}
