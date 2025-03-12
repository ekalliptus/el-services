import 'package:flutter/material.dart';
import 'package:pattern_lock/pattern_lock.dart';
import 'package:google_fonts/google_fonts.dart';

class PatternLockDialog extends StatefulWidget {
  final Function(String) onPatternComplete;

  const PatternLockDialog({
    Key? key,
    required this.onPatternComplete,
  }) : super(key: key);

  @override
  State<PatternLockDialog> createState() => _PatternLockDialogState();
}

class _PatternLockDialogState extends State<PatternLockDialog> {
  String _pattern = '';
  bool _isConfirming = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isConfirming ? 'Konfirmasi Pola' : 'Buat Pola',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _isConfirming
                  ? 'Gambar ulang pola untuk konfirmasi'
                  : 'Gambar pola untuk mengunci perangkat',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (_errorMessage.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                _errorMessage,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.red,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: 16),
            Container(
              width: 300,
              height: 300,
              child: PatternLock(
                selectedColor: Colors.blue,
                notSelectedColor: Colors.grey.shade300,
                pointRadius: 10,
                dimension: 3,
                fillPoints: true,
                onInputComplete: (List<int> input) {
                  final pattern = input.join('-');

                  // Validasi minimal 4 titik
                  if (input.length < 4) {
                    setState(() {
                      _errorMessage = 'Minimal 4 titik diperlukan';
                    });
                    return;
                  }

                  if (!_isConfirming) {
                    setState(() {
                      _pattern = pattern;
                      _isConfirming = true;
                      _errorMessage = '';
                    });
                  } else {
                    if (pattern == _pattern) {
                      widget.onPatternComplete(pattern);
                      Navigator.pop(context);
                    } else {
                      setState(() {
                        _errorMessage = 'Pola tidak cocok, coba lagi';
                        _isConfirming = false;
                        _pattern = '';
                      });
                    }
                  }
                },
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ),
                if (_isConfirming) ...[
                  SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isConfirming = false;
                        _pattern = '';
                        _errorMessage = '';
                      });
                    },
                    style: TextButton.styleFrom(
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(
                      'Ulangi',
                      style: GoogleFonts.poppins(
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
