import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:servicehponline/data/models/device_problems.dart';
import 'package:url_launcher/url_launcher.dart';

class InfoSectionWidget extends StatelessWidget {
  final Map<String, dynamic> service;

  const InfoSectionWidget({
    Key? key,
    required this.service,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informasi Service',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow('Nama', service['fullname']),
          _buildInfoRow('WhatsApp', service['phoneNumber']),
          _buildInfoRow('Alamat', service['address']),
          _buildInfoRow('Masalah',
              DeviceProblems.getProblemName(service['problem'] ?? '')),
          _buildInfoRow('Deskripsi', service['description']),
          _buildInfoRow('Metode Pengiriman', service['shipping_method']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    if (label == 'WhatsApp') {
      return Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Flexible(
              child: Wrap(
                spacing: 8,
                children: [
                  Text(
                    value ?? '-',
                    style: GoogleFonts.poppins(
                      color: Colors.black87,
                    ),
                  ),
                  if (value != null && value.isNotEmpty)
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          final whatsappUrl =
                              'https://wa.me/${value.startsWith('0') ? '62${value.substring(1)}' : value}';
                          launchUrl(Uri.parse(whatsappUrl));
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'Chat',
                              style: GoogleFonts.poppins(
                                color: Colors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: GoogleFonts.poppins(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
