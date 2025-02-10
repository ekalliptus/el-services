// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:servicehponline/data/models/device_problems.dart';
import 'package:google_fonts/google_fonts.dart';

class ServiceCard extends StatelessWidget {
  final Map<String, String> device;
  final String active;
  final Function(String) setActive;
  final VoidCallback nextPage;

  const ServiceCard({
    Key? key,
    required this.device,
    required this.active,
    required this.setActive,
    required this.nextPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isActive = active == device['key'];
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - (48 + 24)) / 3; // Menghitung lebar card

    return GestureDetector(
      onTap: () => setActive(device['key']!),
      child: Container(
        width: cardWidth,
        height: cardWidth * 1.2, // Tinggi card proporsional dengan lebar
        decoration: BoxDecoration(
          color: isActive ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey[300]!,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: cardWidth * 0.5, // Ukuran icon proporsional dengan card
              height: cardWidth * 0.5,
              padding: EdgeInsets.all(cardWidth * 0.1),
              child: SvgPicture.asset(
                device['icon']!,
              ),
            ),
            SizedBox(height: cardWidth * 0.1),
            Text(
              DeviceProblems.getDeviceName(device['key']!),
              style: GoogleFonts.poppins(
                color: isActive ? Colors.white : Colors.black87,
                fontSize: cardWidth * 0.14, // Ukuran font proporsional
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
