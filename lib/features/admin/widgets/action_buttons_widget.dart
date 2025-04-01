import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ActionButtonsWidget extends StatelessWidget {
  final Map<String, dynamic> service;
  final Function(String, String) onUpdateStatus;
  final Function(Map<String, dynamic>) onUpdateCost;

  const ActionButtonsWidget({
    Key? key,
    required this.service,
    required this.onUpdateStatus,
    required this.onUpdateCost,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final status = service['status']?.toString().toUpperCase() ?? 'PENDING';
    final hasServiceCost = service['service_cost'] != null;
    final isProcessedStatus = status == 'PROCESSED';
    final isComplainedStatus = status == 'COMPLAINED';
    final isUnpaidStatus = status == 'UNPAID' || status == 'WAITING_PAYMENT';

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Tombol update status untuk semua status
        _buildStatusButton(
          context,
          status: status,
          isProcessedStatus: isProcessedStatus,
          isComplainedStatus: isComplainedStatus,
          isUnpaidStatus: isUnpaidStatus,
        ),

        // Tombol update biaya hanya untuk PENDING tanpa biaya
        if (status == 'PENDING' && !hasServiceCost)
          _buildCostButton(context, 'Tetapkan Biaya'),

        // Tombol tambah biaya service untuk status PROCESSED
        if (isProcessedStatus)
          _buildCostButton(context, 'Tambah Biaya Service'),
      ],
    );
  }

  Widget _buildStatusButton(
    BuildContext context, {
    required String status,
    required bool isProcessedStatus,
    required bool isComplainedStatus,
    required bool isUnpaidStatus,
  }) {
    // Jika status sudah COMPLETED (Selesai), jangan tampilkan tombol Update Status
    if (status == 'COMPLETED') {
      return SizedBox.shrink(); // Tidak menampilkan tombol
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: PopupMenuButton<String>(
        onSelected: (value) => onUpdateStatus(service['id'].toString(), value),
        itemBuilder: (context) {
          final List<PopupMenuItem<String>> items = [];

          // Pilihan status berdasarkan status saat ini
          if (status == 'PENDING' || isUnpaidStatus || isComplainedStatus) {
            // Dari Menunggu Admin, Belum Dibayar, atau Komplain -> Diproses
            items.add(
              PopupMenuItem(
                value: 'PROCESSED',
                child: _buildStatusMenuItem(
                  'Diproses',
                  Colors.blue,
                ),
              ),
            );
            // Dari status apapun -> Selesai
            items.add(
              PopupMenuItem(
                value: 'COMPLETED',
                child: _buildStatusMenuItem(
                  'Selesai',
                  Colors.green,
                ),
              ),
            );
          } else if (isProcessedStatus) {
            // Dari Diproses -> Selesai
            items.add(
              PopupMenuItem(
                value: 'COMPLETED',
                child: _buildStatusMenuItem(
                  'Selesai',
                  Colors.green,
                ),
              ),
            );
          }

          return items;
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.update, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Update Status',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCostButton(BuildContext context, String label) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () => onUpdateCost(service),
        icon: Icon(Icons.attach_money, color: Colors.white),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMenuItem(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.poppins(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
