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
      ),
      ServiceFilterModel(
        filterKey: 'waiting_payment',
        displayName: 'Belum Dibayar',
      ),
      ServiceFilterModel(
        filterKey: 'processed',
        displayName: 'Diproses',
      ),
      ServiceFilterModel(
        filterKey: 'completed',
        displayName: 'Selesai',
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
