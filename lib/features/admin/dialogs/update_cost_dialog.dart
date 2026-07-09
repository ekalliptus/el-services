import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Menampilkan dialog untuk memperbarui biaya service
Future<void> showUpdateCostDialog(
    BuildContext context, Map<String, dynamic> service,
    {String title = 'Update Biaya Service'}) async {
  final _costController = TextEditingController();
  bool _isSubmitting = false;
  final _supabase = Supabase.instance.client;
  final isComplaint =
      service['status']?.toString().toUpperCase() == 'COMPLAINED';

  if (service['service_cost'] != null) {
    _costController.text = service['service_cost'].toString();
  }

  // Pastikan controller di-dispose setelah dialog ditutup untuk mencegah leak
  // (fungsi top-level tidak punya lifecycle dispose sendiri).
  try {
    await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          title + (isComplaint ? ' (Komplain)' : ''),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isComplaint)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Perbarui biaya service untuk penanganan komplain ini. Status akan otomatis diubah menjadi "Belum Dibayar".',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.red[700],
                  ),
                ),
              ),
            if (title == 'Biaya Service Tambahan')
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Menambahkan biaya service tambahan akan mengubah status menjadi "Belum Dibayar" sehingga pelanggan perlu melakukan pembayaran tambahan.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            TextField(
              controller: _costController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                // Batasi panjang agar nilai tidak melebihi rentang 64-bit.
                LengthLimitingTextInputFormatter(15),
              ],
              decoration: InputDecoration(
                labelText: 'Biaya Service',
                prefixText: 'Rp ',
                border: OutlineInputBorder(),
                hintText: '100000',
              ),
              onChanged: (value) {
                // Optional: Format angka dengan pemisah ribuan
                if (value.isNotEmpty) {
                  // Gunakan tryParse: input digit sangat panjang bisa melebihi
                  // rentang 64-bit dan membuat int.parse melempar FormatException.
                  final number =
                      int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (number == null) return;
                  _costController.text = number.toString();
                  _costController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _costController.text.length),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: Text(
              'BATAL',
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    if (_costController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Biaya service harus diisi'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    setState(() => _isSubmitting = true);

                    try {
                      final cost = int.tryParse(_costController.text);
                      if (cost == null) {
                        setState(() => _isSubmitting = false);
                        return;
                      }
                      // Ubah status menjadi UNPAID jika sebelumnya PENDING, COMPLAINED atau PROCESSED
                      final currentStatus =
                          service['status']?.toString().toUpperCase() ??
                              'PENDING';
                      String newStatus = currentStatus;

                      if (currentStatus == 'PENDING' ||
                          currentStatus == 'COMPLAINED' ||
                          currentStatus == 'PROCESSED' ||
                          title == 'Biaya Service Tambahan') {
                        newStatus = 'UNPAID';
                      }

                      // ponytail: penulisan service_cost/status langsung dari
                      // client. Wajib dilindungi RLS admin-only atau dirutekan
                      // lewat RPC/edge function yang memverifikasi klaim admin —
                      // lihat SECURITY-PAYMENT.md. Jangan percaya write client.
                      await _supabase.from('services').update({
                        'service_cost': cost,
                        'status': newStatus,
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', service['id']);

                      if (!context.mounted) return;
                      Navigator.pop(
                          context, true); // Return true to indicate success

                      String message = 'Biaya service berhasil diupdate';
                      if (currentStatus != newStatus) {
                        message += ' dan status diubah menjadi "Belum Dibayar"';
                      }

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      print('Error updating service cost: $e');
                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal update biaya service'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (context.mounted) {
                        setState(() => _isSubmitting = false);
                      }
                    }
                  },
            child: _isSubmitting
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  )
                : Text(
                    'SIMPAN',
                    style: GoogleFonts.poppins(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
  } finally {
    _costController.dispose();
  }
}
