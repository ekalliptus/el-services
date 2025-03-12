import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Menampilkan dialog untuk memperbarui biaya service
Future<void> showUpdateCostDialog(
    BuildContext context, Map<String, dynamic> service) async {
  final _costController = TextEditingController();
  bool _isSubmitting = false;
  final _supabase = Supabase.instance.client;

  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          'Update Biaya Service',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _costController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
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
                  final number =
                      int.parse(value.replaceAll(RegExp(r'[^0-9]'), ''));
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
                      final cost = int.parse(_costController.text);
                      await _supabase.from('services').update({
                        'service_cost': cost,
                        'updated_at': DateTime.now().toIso8601String(),
                      }).eq('id', service['id']);

                      if (!context.mounted) return;
                      Navigator.pop(
                          context, true); // Return true to indicate success

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Biaya service berhasil diupdate'),
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
}
