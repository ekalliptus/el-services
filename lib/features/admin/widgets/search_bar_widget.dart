import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onChanged;
  final String hintText;
  final VoidCallback? onClear;

  const SearchBarWidget({
    Key? key,
    required this.controller,
    required this.onChanged,
    this.hintText = 'Cari berdasarkan nama, ID, model, merk...',
    this.onClear,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 4),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Pencarian mendukung: nama, nomor HP, model, merk, ID service, dll',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.blue[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[400],
                fontSize: 14,
              ),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[600]),
                      onPressed: () {
                        controller.clear();
                        if (onClear != null) {
                          onClear!();
                        } else {
                          onChanged('');
                        }
                      },
                      tooltip: 'Hapus pencarian',
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
              filled: true,
              fillColor: Colors.white,
            ),
            style: GoogleFonts.poppins(
              fontSize: 14,
            ),
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
          ),
        ),
      ],
    );
  }
}
