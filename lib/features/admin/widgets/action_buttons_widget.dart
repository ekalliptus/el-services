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
    final isPendingWithoutCost = status == 'PENDING' && !hasServiceCost;
    final isComplainedStatus = status == 'COMPLAINED';
    final isProcessedStatus = status == 'PROCESSED';
    final isCompletedStatus = status == 'COMPLETED';
    final isWaitingPaymentStatus = status == 'WAITING_PAYMENT';

    // Jika status sudah selesai, nonaktifkan semua tombol
    if (isCompletedStatus) {
      return IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: null, // Dinonaktifkan
                  icon: Icon(Icons.attach_money, color: Colors.white70),
                  label: Text(
                    'Update Biaya',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.6),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.update, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'Update Status',
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => onUpdateCost(service),
                icon: Icon(Icons.attach_money, color: Colors.white),
                label: Text(
                  'Update Biaya',
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
            ),
          ),
          if (!isPendingWithoutCost) ...[
            SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: PopupMenuButton<String>(
                  onSelected: (value) =>
                      onUpdateStatus(service['id'].toString(), value),
                  itemBuilder: (context) {
                    List<PopupMenuItem<String>> items = [];

                    // Pilihan status berdasarkan status saat ini
                    if (status == 'PENDING') {
                      // Status PENDING: bisa ke semua status
                      items.add(
                        PopupMenuItem(
                          value: 'WAITING_PAYMENT',
                          child: _buildStatusMenuItem(
                            'Belum Dibayar',
                            Colors.orange,
                          ),
                        ),
                      );
                      items.add(
                        PopupMenuItem(
                          value: 'PROCESSED',
                          child: _buildStatusMenuItem(
                            'Diproses',
                            Colors.blue,
                          ),
                        ),
                      );
                      items.add(
                        PopupMenuItem(
                          value: 'COMPLETED',
                          child: _buildStatusMenuItem(
                            'Selesai',
                            Colors.green,
                          ),
                        ),
                      );
                    } else if (isWaitingPaymentStatus || isComplainedStatus) {
                      // Belum Dibayar atau Komplen: hanya bisa ke DiProses atau Selesai
                      items.add(
                        PopupMenuItem(
                          value: 'PROCESSED',
                          child: _buildStatusMenuItem(
                            'Diproses',
                            Colors.blue,
                          ),
                        ),
                      );
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
                      // DiProses: hanya bisa ke Selesai
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
              ),
            ),
          ],
        ],
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
